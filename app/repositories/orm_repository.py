from __future__ import annotations

from typing import Any, TypeVar

from sqlalchemy import Select, asc, desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.sql import ColumnElement
from sqlalchemy.sql.selectable import Subquery


class Base(DeclarativeBase):
    pass


ModelT = TypeVar("ModelT", bound=Base)

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
    - field__subquery=subquery
    """

    def __init__(self, session: AsyncSession):
        self.session = session

    async def insert(
        self,
        obj: ModelT,
        *,
        flush: bool = True,
        commit: bool = False,
    ) -> ModelT:
        """
        Add an object to the current session.
        """
        self.session.add(obj)

        if flush:
            await self.session.flush()

        if commit:
            await self.session.commit()

        return obj

    async def select(
        self,
        cls: type[ModelT],
        obj_id: Any | None = None,
        **filters: Any,
    ) -> ModelT | None:
        """
        Return the first matching object or None.

        Examples:
            await manager.select(User, 1)
            await manager.select(User, id=1)
            await manager.select(User, email="a@b.com")
            await manager.select(User, age__ge=18)
        """
        query = select(cls)

        if obj_id is not None:
            filters[ID] = obj_id

        query = query.where(*self._build_where(cls, **filters)).limit(1)

        result = await self.session.execute(query)
        return result.scalars().first()

    async def update(
        self,
        obj: ModelT,
        *,
        flush: bool = True,
        commit: bool = False,
    ) -> ModelT:
        """
        Persist changes for an object already attached to the session.

        For the normal ORM flow, load object -> mutate fields -> update().
        """
        if flush:
            await self.session.flush()

        if commit:
            await self.session.commit()

        return obj

    async def delete(
        self,
        obj: ModelT,
        *,
        flush: bool = True,
        commit: bool = False,
    ) -> None:
        """
        Delete an ORM object.
        """
        await self.session.delete(obj)

        if flush:
            await self.session.flush()

        if commit:
            await self.session.commit()

    async def list(
        self,
        cls: type[ModelT],
        **filters: Any,
    ) -> list[ModelT]:
        """
        Return a list of matching objects.

        Reserved kwargs:
            order_by="created_at"
            order="asc" | "desc" | "rand"
            offset=0
            limit=100
        """
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
    ) -> Subquery:
        """
        Build a subquery that selects exactly one column.

        Example:
            subq = manager.make_subquery(Post, "user_id", published=True)
            users = await manager.list(User, id__subquery=subq)
        """
        column = self._get_column(cls, column_name)
        query = select(column).where(*self._build_where(cls, **filters))
        return query.subquery()

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
                conditions.append(column.in_(self._normalize_subquery(value)))
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
        """
        Examples:
            "id" -> ("id", "eq")
            "age__ge" -> ("age", "ge")
            "id__subquery" -> ("id", "subquery")
        """
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

    def _normalize_subquery(self, value: Any):
        """
        Accept a SQLAlchemy Select or Subquery-like object for IN (subquery).
        """
        if hasattr(value, "select"):
            return value.select()

        return value