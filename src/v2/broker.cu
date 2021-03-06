#include "trade.h"

#define FEE_TAKER 0.0004
#define FEE_MAKER 0.0002

Broker newBroker(Data data) {
    Broker broker;
    broker.cursor = 0;
    broker.minutes = data.minutes;
    broker.nbrMinutes = data.nbrMinutes;
    broker.bank = 0;
    broker.seed = plantSeed();
    broker.fees = 0;
    broker.bet.type = NO_BET;
    broker.bet.closeDown = 0;
    broker.bet.closeUp = 0;
    broker.nbrBets = 0;
    broker.reg = 0;
    broker.lastRegBank = broker.bank;
    return broker;
}

#define MINUTE broker->minutes[broker->cursor]
#define SIZE_BET 1

DEVICE static void closeBet(Broker *broker, int isWin, double diff) {
    broker->bet.totalFee += SIZE_BET * FEE_TAKER;
    double gain = SIZE_BET * (isWin == 1 ? diff : -diff);
    broker->bank += gain;
    broker->bet.totalFee = (FEE_TAKER * SIZE_BET);
    broker->bet.totalFee +=
        ((isWin == 1 ? FEE_MAKER : FEE_TAKER) * (SIZE_BET + gain));
    broker->fees += broker->bet.totalFee;
    broker->bank += -broker->bet.totalFee;
    broker->nbrBets += 1;

#ifdef PLAY
    // fprintf(fp, "%lf,%lf,%lf\n", broker->minutes[broker->cursor].close,
    //         broker->bank, broker->fees);

    printf(
        "%s%-4s DIFF: %-5.04lf STH: %-5.04lf STL: %-5.04lf GAIN: "
        "%-5.04lf FEE :%-8.05lf\n",
        (isWin == 1 ? "\x1B[32m" : "\x1B[31m"),
        (broker->bet.type == SELL ? "SELL" : "BUY"), diff, broker->bet.closeUp,
        broker->bet.closeDown, gain, broker->bet.totalFee);
    printMinute(&broker->minutes[broker->bet.cursor], broker->bet.cursor);
    printMinute(&broker->minutes[broker->cursor], broker->cursor);
    printf("BK: %-8.04lf FEE: %-8.02lf NB: %-5d\n", broker->bank, broker->fees,
           broker->nbrBets);
    printf(
        "\x1B[0m---------------------------------------------------------------"
        "-------------------------------------------\n");

#endif
#ifdef REPLAY
    getchar();
#endif
    broker->bet.type = NO_BET;
}

DEVICE void printCandles(Minute *minute, int amount) {
    FILE *f = fopen("replay.csv", "w");
    fprintf(f, "Date,Open,High,Low,Close,Volume\n");
    for (int i = 0; i < amount; i++) {
        fprintf(f, "%ld,%lf,%lf,%lf,%lf,%lf\n", minute[i].time,minute[i].open,
                minute[i].high, minute[i].low, minute[i].close,
                minute[i].volume);
    }
    fclose(f);
}

DEVICE void tickBroker(Broker *broker) {
    if (broker->cursor % BROKER_REG_STEP == 0) {
        broker->reg += (broker->bank > broker->lastRegBank) ? 1 : -1;
        broker->lastRegBank = broker->bank;
    }
    if (broker->bet.type == NO_BET) {
        analyse(&MINUTE, &broker->seed, &broker->bet);
        if (broker->bet.type != NO_BET) {
            broker->bet.cursor = broker->cursor;

#ifdef REPLAY
            // FILE *f = fopen("replay.csv", "w");
            // fprintf(f, "price, bet, up, down\n");
            // for (int i = broker->bet.cursor - 400; i < broker->cursor + 100;
            //      i++) {
            //     fprintf(f, "%lf,%lf,%lf,%lf\n", broker->minutes[i].close,
            //             (i <= broker->bet.cursor)
            //                 ? broker->minutes[broker->bet.cursor].close
            //                 : 0,
            //             broker->bet.closeUp, broker->bet.closeDown);
            // }
            // fclose(f);
            broker->minutes[broker->cursor].low += -200;
            broker->minutes[broker->cursor].high += 200;
            printCandles(&broker->minutes[broker->cursor-200], 400);
            broker->minutes[broker->cursor].low += 200;
            broker->minutes[broker->cursor].high += -200;
#endif
        }
        return;
    } else if (broker->bet.type == SELL) {
        if (MINUTE.high >= broker->bet.closeUp) {
            double diff = fabs((broker->bet.closeUp /
                                broker->minutes[broker->bet.cursor].close) -
                               1);
            // LOSE
            closeBet(broker, 0, diff);
        } else if (MINUTE.low < broker->bet.closeDown) {
            // WIN
            double diff = fabs((broker->bet.closeDown /
                                broker->minutes[broker->bet.cursor].close) -
                               1);
            closeBet(broker, 1, diff);
        }
    } else if (broker->bet.type == BUY) {
        if (MINUTE.low <= broker->bet.closeDown) {
            // LOSE
            double diff = fabs((broker->bet.closeDown /
                                broker->minutes[broker->bet.cursor].close) -
                               1);
            closeBet(broker, 0, diff);
        } else if (MINUTE.high > broker->bet.closeUp) {
            // WIN
            double diff = fabs((broker->bet.closeUp /
                                broker->minutes[broker->bet.cursor].close) -
                               1);
            closeBet(broker, 1, diff);
        }
    }
}
