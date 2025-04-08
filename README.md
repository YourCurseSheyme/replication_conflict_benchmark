# Replication conflict benchmark

A small benchmark on possible replication conflicts developed while in the Tarantool Lab, as well as a simple tool for
automatic conflict resolution. The examples given represent different variations of conflicts, reflecting some form of
connection to the system, linkage to physical processes and business logic. Each example is described in more detail
at the appropriate folder.

The purpose of benchmark is to investigate the behavior of the system under test in resolving emerging conflicts,
finding potential mistakes in the work, as well as handling non-standard cases.

1. [Conflict examples](#Conflict-examples)
2. [Metrics](#Potential-metrics)
3. [Environment](#Environment)
4. [How to run](#How-to-run)

---

## Conflict examples

Simple description of each of the examples:

- 1
- 2
- 3

---

## Potential metrics

| Metric             | Description                              | Tools                       |
|--------------------|------------------------------------------|-----------------------------|
| Resolution quality | Conflict resolution quality heuristic    | Tester evaluation           |
| Resolution time    | How quickly the system reaches consensus | `box.stat` and logs         |
| Replication delay  | `vclock` difference between replicas     | Tarantool build-in metrics  |

---

## Environment

- Tarantool 2.1+ or any other DB-system
- Lua
- Docker (optionally)

---

## How to run

Disclaimer: Tarantool tests

1. Clone the repository

```bash
git clone https://github.com/YourCurseSheyme/replication_conflict_benchmark.git
cd replication_conflict_benchmark
```

2. Run script to choose a test

```bash
cd scripts
./run_tests.sh
```

3. Take a look at the suggested steps for reaching a conflict situation and apply them

```bash
less test_data.md
```
