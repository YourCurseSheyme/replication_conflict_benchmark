# Test 1

## Steps as SQL queries

1. Initial data entry under active replication

```sql
insert into accounts values (1, 500), (2, 300);
```

2. Disconnecting replication using Tarantool as an example

```lua
original_replication = box.cfg.replication
box.cfg{replication = {}}
```

3. Second node separated insertion

```sql
insert into accounts values (3, 700);
```

4. First node separated insertion and recovering replication

```sql
insert into accounts values (3, 1000);
```

```lua
box.cfg{replication = original_replication}

Duplicate key exists in unique index "acc_id"
in space "accounts" with old tuple - [3, 700]
and new tuple - [3, 1000]
```