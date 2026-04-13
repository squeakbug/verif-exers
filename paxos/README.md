# Paxos

## Examples

### Simulation

```bash
# 100 steps of simulations
spin -u100 paxos.pml
# or with debug output
spin -v -u50 paxos.pml
```

### Safeness check

```bash
../scripts/spinsafe paxos.pml
# or with smart finite-automata encoding (same, but fast)
../scripts/spinsafe --bitstate paxos.pml
```

### Liveness check

```bash
../scripts/spinlive paxos.pml
# or
../scripts/spinlive --bitstate paxos.pml
```

### Other LTL-expresses properties

```bash
# check by name
../scripts/spinltl paxos.pml agreement_0
../scripts/spinltl paxos.pml validity
../scripts/spinltl paxos.pml termination
# or
../scripts/spinltl --bitstate paxos.pml agreement_0
../scripts/spinltl --bitstate paxos.pml termination
```

### Run trail files

Trail files are generated after simulation fail

```bash
# run simulation fed with trail file
../scripts/spinplay paxos.pml
# or
../scripts/spinplay paxos.pml 100
```

### Other

Eventually spin fails... You can generate program with simulation:

```bash
spin -a paxos.pml
cc -DSAFETY -DNOCLAIM -O2 pan.c -o pan
time ./pan -b -m1000000
cc -DBITSTATE -O2 pan.c -o pan
time ./pan -b -m1000000 -w28
```

Properties checking:

```bash
cc -O2 pan.c -o pan
./pan -a -N agreement_0
```

## Ссылки

См. [docs/references.md](docs/references.md).
