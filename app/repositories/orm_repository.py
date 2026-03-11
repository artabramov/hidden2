from typing import Any
from sqlalchemy import Select, asc, desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import ColumnElement
from app.db import Base


ID = "id"
ORDER_BY = "order_by"
ORDER = "order"
OFFSET = "offset"
LIMIT = "limit"
ASC = "asc"
DESC = "desc"
RAND = "rand"

RESERVED_KEYS = {ORDER_BY, ORDER, OFFSET, LIMIT}


class ORMRepository:
    """
    Generic async repository for SQLAlchemy ORM models. Provides basic
    CRUD operations, filtering, ordering, pagination, and utilities for
    building dynamic queries.

    Filtering syntax:
    - field=value
    - field__eq=value
    - field__ne=value
    - field__gt=value
    - field__ge=value
    - field__lt=value
    - field__le=value
    - field__in=[...]
    - field__like="abc%"
    - field__ilike="%abc%"
    - field__is=None
    - field__isnot=None
    - field__subquery=select(...)
    """

    def __init__(self, session: AsyncSession):
        self.session = session

    async def insert(
        self,
        obj: Base,
        *,
        flush: bool = True,
        commit: bool = False,
    ) -> Base:
        self.session.add(obj)

        if flush:
            await self.session.flush()

        if commit:
            await self.session.commit()

        return obj

    async def select(
        self,
        cls: type[Base],
        obj_id: Any | None = None,
        **filters: Any,
    ) -> Base | None:
        if obj_id is not None and ID in filters:
            raise ValueError("Use either obj_id or id filter, not both")

        query = select(cls)

        if obj_id is not None:
            filters[ID] = obj_id

        query = query.where(*self._build_where(cls, **filters)).limit(1)

        result = await self.session.execute(query)
        return result.scalars().first()

    async def update(
        self,
        obj: Base,
        *,
        flush: bool = True,
        commit: bool = False,
    ) -> Base:
        if flush:
            await self.session.flush()

        if commit:
            await self.session.commit()

        return obj

    async def delete(
        self,
        obj: Base,
        *,
        flush: bool = True,
        commit: bool = False,
    ) -> None:
        await self.session.delete(obj)

        if flush:
            await self.session.flush()

        if commit:
            await self.session.commit()

    async def select_all(
        self,
        cls: type[Base],
        **filters: Any,
    ) -> list[Base]:
        query = select(cls).where(*self._build_where(cls, **filters))
        query = self._apply_ordering(cls, query, **filters)
        query = self._apply_pagination(query, **filters)

        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()

    def make_subquery(
        self,
        cls: type[Base],
        column_name: str,
        **filters: Any,
    ):
        column = self._get_column(cls, column_name)
        return select(column).where(*self._build_where(cls, **filters))

    def _build_where(
        self,
        cls: type[Base],
        **filters: Any,
    ) -> list[ColumnElement[bool]]:
        conditions: list[ColumnElement[bool]] = []

        for key, value in filters.items():
            if key in RESERVED_KEYS:
                continue

            column_name, operator = self._split_filter_key(key)
            column = self._get_column(cls, column_name)

            if operator == "eq":
                conditions.append(column == value)
            elif operator == "ne":
                conditions.append(column != value)
            elif operator == "gt":
                conditions.append(column > value)
            elif operator == "ge":
                conditions.append(column >= value)
            elif operator == "lt":
                conditions.append(column < value)
            elif operator == "le":
                conditions.append(column <= value)
            elif operator == "in":
                if not isinstance(value, (list, tuple, set)):
                    raise TypeError(
                        f"Filter '{key}' expects list, tuple, or set, got {type(value).__name__}"
                    )
                conditions.append(column.in_(value))
            elif operator == "like":
                if not isinstance(value, str):
                    raise TypeError(f"Filter '{key}' expects str")
                conditions.append(column.like(value))
            elif operator == "ilike":
                if not isinstance(value, str):
                    raise TypeError(f"Filter '{key}' expects str")
                conditions.append(column.ilike(value))
            elif operator == "is":
                conditions.append(column.is_(value))
            elif operator == "isnot":
                conditions.append(column.is_not(value))
            elif operator == "subquery":
                conditions.append(column.in_(value))
            else:
                raise ValueError(
                    f"Unsupported operator '{operator}' in filter '{key}'"
                )

        return conditions

    def _apply_ordering(
        self,
        cls: type[Base],
        query: Select[Any],
        **filters: Any,
    ) -> Select[Any]:
        order_by_name = filters.get(ORDER_BY)
        order = filters.get(ORDER, ASC)

        if order == RAND:
            from sqlalchemy import func
            return query.order_by(func.random())

        if order_by_name is None:
            return query

        column = self._get_column(cls, order_by_name)

        if order == ASC:
            return query.order_by(asc(column))
        if order == DESC:
            return query.order_by(desc(column))

        raise ValueError(
            f"Unsupported order '{order}'. Expected 'asc', 'desc', or 'rand'"
        )

    def _apply_pagination(
        self,
        query: Select[Any],
        **filters: Any,
    ) -> Select[Any]:
        offset = filters.get(OFFSET)
        limit = filters.get(LIMIT)

        if offset is not None:
            if not isinstance(offset, int) or offset < 0:
                raise ValueError("offset must be a non-negative integer")
            query = query.offset(offset)

        if limit is not None:
            if not isinstance(limit, int) or limit < 0:
                raise ValueError("limit must be a non-negative integer")
            query = query.limit(limit)

        return query

    def _split_filter_key(self, key: str) -> tuple[str, str]:
        if "__" not in key:
            return key, "eq"

        column_name, operator = key.rsplit("__", 1)

        if not column_name:
            raise ValueError(f"Invalid filter key '{key}'")

        return column_name, operator

    def _get_column(self, cls: type[Base], column_name: str):
        if not hasattr(cls, column_name):
            raise AttributeError(
                f"Model '{cls.__name__}' has no mapped attribute '{column_name}'"
            )
        return getattr(cls, column_name)
