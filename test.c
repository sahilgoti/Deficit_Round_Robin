#include <stdbool.h>
#include <stdio.h>

#define NUM_REQUESTERS 4
#define QUANTUM 64

typedef struct {
  int id;
  int deficit_counter; // Current accumulated credits
  int packet_size;     // Size of current packet to send
  bool req;            // Request active flag
} Requester;

void print_status(Requester reqs[]) {
  printf("State: ");
  for (int i = 0; i < NUM_REQUESTERS; i++) {
    printf("[R%d: Deficit=%3d, Pkt=%3d, Req=%d] ", reqs[i].id,
           reqs[i].deficit_counter, reqs[i].packet_size, reqs[i].req);
  }
  printf("\n");
}

int main() {
  // Initial setup with varying packet sizes
  Requester reqs[NUM_REQUESTERS] = {
      {.id = 0,
       .deficit_counter = 0,
       .packet_size = 40,
       .req = true}, // Small packet
      {.id = 1,
       .deficit_counter = 0,
       .packet_size = 40,
       .req = true}, // Large packet (> 64)
      {.id = 2,
       .deficit_counter = 0,
       .packet_size = 64,
       .req = true}, // Exact quantum
      {.id = 3,
       .deficit_counter = 0,
       .packet_size = 60,
       .req = false} // Not requesting
  };

  printf("=== Starting DRR Simulation (Quantum = %d bytes) ===\n\n", QUANTUM);

  // Simulate 3 rounds of arbitration
  for (int round = 1; round <= 3; round++) {
    printf("--- Round %d ---\n", round);

    for (int i = 0; i < NUM_REQUESTERS; i++) {
      // Step 1: Every round, add Quantum to active requesters
      reqs[i].deficit_counter += QUANTUM;
      printf("Turn: Requester %d | Added +%d credits (Total: %d)\n", reqs[i].id,
             QUANTUM, reqs[i].deficit_counter);

      // Step 2: Check Grant or Skip condition
      if (reqs[i].req) {
        if (reqs[i].deficit_counter >= reqs[i].packet_size) {
          // GRANT: Sufficient credits
          printf("  -> [GRANT] Transmitted %d bytes! ", reqs[i].packet_size);
          reqs[i].deficit_counter -= reqs[i].packet_size;
          printf("Remaining Deficit: %d\n", reqs[i].deficit_counter);

          // Clear request or load a new packet
          reqs[i].req = false;
        } else {
          // SKIP: Insufficient credits
          printf("  -> [SKIP] Needs %d bytes, only has %d. Credits saved for "
                 "next round.\n",
                 reqs[i].packet_size, reqs[i].deficit_counter);
        }
      } else {
        printf("  -> [IDLE] No pending request.\n");
      }
    }

    print_status(reqs);
    printf("\n");
  }

  return 0;
}