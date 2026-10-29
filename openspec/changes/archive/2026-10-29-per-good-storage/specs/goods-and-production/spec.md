## REMOVED Requirements

### Requirement: Producers rest while the stores hold plenty
**Reason**: Stores now hold each good separately and producers ship only where there is room (`warehouses-and-logistics`), which caps every good, including those only houses use, that resting never covered. Measured on main, per-good storage gives the same pacing with the rest rule on and off: 173 of 180 arms reach a merchant and none goes bankrupt (design D4).
**Migration**: The `restAt` field leaves the goods schema and the packs, and the resting building issue and inspector line are removed. A producer whose output has nowhere to go now stops on its own and reports output stuck.
