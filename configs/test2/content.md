# Test 2

## Steps as SQL queries

1. Initial data entry under active replication

```sql
insert into customers values (1, 'BabyBoi'), (2, 'BabyGirl');
insert into accounts values (101, 1, 500), (102, 2, 300);
```

2. Disconnecting replication using Tarantool as an example

```lua
original_replication = box.cfg.replication
box.cfg{replication = {}}
```

3. First node separated adding a new account

```sql
insert into accounts values (103, 1, 1000);
```

4. First node transaction

```sql
begin
insert into operations values (1, 103, 102, 50, 'completed');
update accounts set balance = balance - 50 where account_id = 103;
update accounts set balance = balance + 50 where account_id = 102;
commit;
```

5. Second node separated adding a new account

```sql
insert into accounts values (103, 2, 1000);
```

6. Second node transactions

```sql
begin
insert into operations values (1, 0, 103, 50, 'completed');
update accounts set balance = balance + 50 where account_id = 103;
commit;
```

```sql
begin
insert into operations values (2, 102, 103, 50, 'completed');
update accounts set balance = balance - 50 where account_id = 102;
update accounts set balance = balance + 50 where account_id = 103;
commit;
```

7. Recovering replication

```lua
box.cfg{replication = original_replication}
```