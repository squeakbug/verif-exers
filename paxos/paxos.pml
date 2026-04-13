#define NACCEPTORS 3
#define NPROPOSERS 3
#define NLEARNERS 2
#define QUORUM (NACCEPTORS / 2 + 1)

mtype = {
  PREPARE,
  PROMISE,
  ACCEPT,
  ACCEPTED,
  DECISION
};

typedef prepare_chans {
  chan chans[NACCEPTORS] = [1] of { mtype };
}

typedef promise_chans {
  chan chans[NACCEPTORS] = [1] of { short, short, short };
}

typedef accept_chans {
  chan chans[NACCEPTORS] = [1] of { short };
}

typedef learn_chans {
  chan chans[NACCEPTORS] = [NPROPOSERS] of { short, short };
};

prepare_chans prepare[NPROPOSERS];
promise_chans promise[NPROPOSERS];
accept_chans accept[NPROPOSERS];
learn_chans learn[NLEARNERS];

/* Global decision state */
bool decided = false;
byte final_value = 0;

byte first_decided_value = 0;
bool first_decided_set = false;

byte mcount[NPROPOSERS];

/* Broadcast prepare messages to all acceptors */
inline bprepare(round) {
  byte j = 0;
  do
  :: (j < NACCEPTORS) ->
    prepare[round].chans[j] ! PREPARE;
    j++;
  :: (j >= NACCEPTORS) -> break;
  od
}

/* Broadcast accept messages to all acceptors */
inline baccept(round, v) {
  byte k = 0;
  do
  :: (k < NACCEPTORS) ->
    accept[round].chans[k] ! v;
    k++;
  :: (k >= NACCEPTORS) -> break;
  od
}

/* Proposer: send prepares, collect promises, send accepts, terminate */
proctype proposer(short crnd; short myval) {
  short hr = -1, hv = -1;
  short prnd_r, prnd_prnd, prnd_pval;
  byte count = 0;
  byte i = 0;
  short aux;

  /* Phase 1a: Send PREPARE to all acceptors */
  bprepare(crnd);

  /* Phase 1b: Collect PROMISEs until quorum */
  do
  :: (count < QUORUM && i < NACCEPTORS) ->
    if
    :: (nempty(promise[crnd].chans[i])) ->
progress_proposer_collect:
      promise[crnd].chans[i] ? prnd_r, prnd_prnd, prnd_pval;
      count++;
      if
      :: (prnd_prnd > hr) ->
        hr = prnd_prnd;
        hv = prnd_pval;
      :: (prnd_prnd <= hr) -> skip;
      fi;
      i++;
    :: (empty(promise[crnd].chans[i])) ->
      i++;
    fi;
  :: (count >= QUORUM) -> break;
  :: (i >= NACCEPTORS && count < QUORUM) -> break;
  od;

  /* Phase 2a: Determine value and send ACCEPT to all acceptors */
  aux = (hr < 0 -> myval : hv);
  baccept(crnd, aux);
}

/* Acceptor: process prepares then accepts, then terminate */
proctype acceptor(int id) {
  short crnd = -1;
  short prnd = -1, pval = -1;
  short aval = 0;
  byte rnd;
  mtype msg;
  byte lrn;

  /* Phase 1: Handle all incoming PREPARE messages */
  rnd = 0;
  do
  :: (rnd < NPROPOSERS) ->
    if
    :: (nempty(prepare[rnd].chans[id])) ->
progress_acceptor_prepare:
      prepare[rnd].chans[id] ? msg;
      if
      :: (rnd > crnd) -> crnd = rnd;
      :: (rnd <= crnd) -> skip;
      fi;
      promise[rnd].chans[id] ! crnd, prnd, pval;
    :: (empty(prepare[rnd].chans[id])) -> skip;
    fi;
    rnd++;
  :: (rnd >= NPROPOSERS) -> break;
  od;

  /* Phase 2: Handle all incoming ACCEPT messages */
  rnd = 0;
  do
  :: (rnd < NPROPOSERS) ->
    if
    :: (nempty(accept[rnd].chans[id])) ->
progress_acceptor_accept:
      accept[rnd].chans[id] ? aval;
      if
      :: (rnd >= crnd) ->
        crnd = rnd;
        prnd = rnd;
        pval = aval;
        lrn = 0;
        do
        :: (lrn < NLEARNERS) ->
          learn[lrn].chans[id] ! crnd, aval;
          lrn++;
        :: (lrn >= NLEARNERS) -> break;
        od;
      :: (rnd < crnd) -> skip;
      fi;
      aval = 0;
    :: (empty(accept[rnd].chans[id])) -> skip;
    fi;
    rnd++;
  :: (rnd >= NPROPOSERS) -> break;
  od;
}

/* Learner: collect learn messages until quorum for some round, then terminate */
proctype learner(int id) {
  short lastval = -1, rnd, lval;
  byte count = 0;

  do
  :: (count < NACCEPTORS) ->
    if
    :: (nempty(learn[id].chans[count])) ->
progress_learner_learn:
      learn[id].chans[count] ? rnd, lval;
      mcount[rnd]++;
      if
      :: (mcount[rnd] >= QUORUM) ->
        if
        :: (lastval == -1) -> lastval = lval;
        :: (lastval >= 0 && lastval != lval) ->
          assert(false); /* Agreement violation */
        :: (lastval >= 0 && lastval == lval) -> skip;
        fi;
        decided = true;
        final_value = lastval;
        if
        :: (!first_decided_set) ->
          first_decided_value = lastval;
          first_decided_set = true;
        :: (first_decided_set) -> skip;
        fi;
        break;
      :: (mcount[rnd] < QUORUM) -> skip;
      fi;
    :: (empty(learn[id].chans[count])) -> skip;
    fi;
    count++;
  :: (count >= NACCEPTORS) -> break;
  od;
}

init {
  atomic {
    int i;
    for (i : 0 .. (NLEARNERS - 1)) {
      run learner(i);
    };
    int j;
    for (j : 0 .. (NPROPOSERS - 1)) {
      run proposer(j, j);
    };
    int k;
    for (k : 0 .. (NACCEPTORS - 1)) {
      run acceptor(k);
    };
  };
}

/* ========== Определение консенсуса ========== */

/* Если в какой-то момент значение стало выбранным, то оно остается быть выбранным (здесь используется булева переменная (уже выбрано/еще не выбрано) + выбранное значение) */
ltl irrevocable { [](decided -> [] decided) }

/* Если в какой-то момент выбрано v, это (а не какое-либо другое) значение остается после этого момента выбранным */
ltl agreement_0 { [](decided && final_value == 0 -> [](decided -> final_value == 0)) }
ltl agreement_1 { [](decided && final_value == 1 -> [](decided -> final_value == 1)) }
ltl agreement_2 { [](decided && final_value == 2 -> [](decided -> final_value == 2)) }

/* Только предлагаемые значение могут быть когда-либо выбраны */
ltl validity {
  [] (decided -> (final_value == 0 || final_value == 1 || final_value == 2))
}

/* Решение может быть принято тогда и только тогда, когда проголосовало большиство */
ltl quorum_needed {
  [] (decided ->
    (mcount[0] >= QUORUM || mcount[1] >= QUORUM || mcount[2] >= QUORUM))
}

/* ======== Свойства живости ======== */

/* Значение когда-нибудь будет выбрано */
ltl termination { <> decided }

/* ======== Свойства безопасности ======== */

