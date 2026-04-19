# Jira Board (Architect Authority)

This file is the canonical ticket board for active core execution.

## Board Rules

- Ticket IDs are immutable (`CZH-###`).
- One ticket maps to one commit unless explicitly marked `atomic-pair`.
- Engineer executes tickets in listed order unless a dependency says otherwise.
- Engineer does not reorder, merge, or split tickets without Architect approval.
- Architect is the only role allowed to move tickets into `review_gate` and `done`.
- Architect cadence: prefer one review at super-gate after a longer engineer
  loop (target 8–14 commits) unless a real hard blocker appears.

## Status Columns

- `todo`: scoped, ready, not started.
- `in_progress`: active execution ticket (max 1).
- `blocked`: waiting on architecture/product decision.
- `changes_required`: architect rejected the gate; follow-up batch owns correction.
- `review_gate`: checkpoint reached; awaiting Architect review.
- `done`: Architect accepted ticket outcome.

## Current Sprint

- Sprint ID: `CZH-S31`
- Previous Sprint: `CZH-S30` (changes required)
- Super-gate: `CZH-GATE-90` (CZH-B36, `in_progress`)

## Ticket Order (`CZH-S31`)

1. `CZH-851`
2. `CZH-852`
3. `CZH-853`
4. `CZH-854`
5. `CZH-855`
6. `CZH-856`
7. `CZH-857`
8. `CZH-858`
9. `CZH-859`
10. `CZH-860`

## Current State

- `in_progress`: `CZH-851`
- `todo`: `CZH-852`, `CZH-853`, `CZH-854`, `CZH-855`, `CZH-856`, `CZH-857`, `CZH-858`, `CZH-859`, `CZH-860`
- `blocked`: none
- `changes_required`: `CZH-B35` at `CZH-GATE-89`
- `review_gate`: none
- `done`: `CZH-B1`, `CZH-B2`, `CZH-B3`, `CZH-B4`, `CZH-B5` (accepted as a narrow hygiene slice), `CZH-B6` (accepted), `CZH-B7` (accepted), `CZH-B8` (accepted), `CZH-B9` (accepted), `CZH-B10` (accepted), `CZH-B11` (accepted), `CZH-B12` (accepted), `CZH-B13` (accepted), `CZH-B14` (accepted), `CZH-B15` (accepted), `CZH-B16` (accepted), `CZH-B17` (accepted), `CZH-B18` (accepted), `CZH-B19` (accepted), `CZH-B20` (accepted), `CZH-B21` (accepted), `CZH-B22` (accepted), `CZH-B23` (accepted), `CZH-B24` (accepted), `CZH-B25` (accepted), `CZH-B26` (accepted), `CZH-B27` (accepted), `CZH-B28` (accepted), `CZH-B29` (accepted), `CZH-B30` (accepted), `CZH-B31` (accepted), `CZH-B32` (accepted), `CZH-B33` (accepted), `CZH-B34` (accepted), `CZH-601`, `CZH-602`, `CZH-603`, `CZH-604`, `CZH-605`, `CZH-606`, `CZH-607`, `CZH-608`, `CZH-609`, `CZH-610`, `CZH-611`, `CZH-612`, `CZH-613`, `CZH-614`, `CZH-615`, `CZH-616`, `CZH-617`, `CZH-618`, `CZH-619`, `CZH-620`, `CZH-621`, `CZH-622`, `CZH-623`, `CZH-624`, `CZH-625`, `CZH-626`, `CZH-627`, `CZH-628`, `CZH-629`, `CZH-630`, `CZH-631`, `CZH-632`, `CZH-633`, `CZH-634`, `CZH-635`, `CZH-636`, `CZH-637`, `CZH-638`, `CZH-639`, `CZH-640`, `CZH-641`, `CZH-642`, `CZH-643`, `CZH-644`, `CZH-645`, `CZH-646`, `CZH-647`, `CZH-648`, `CZH-649`, `CZH-650`, `CZH-651`, `CZH-652`, `CZH-653`, `CZH-654`, `CZH-655`, `CZH-656`, `CZH-657`, `CZH-658`, `CZH-659`, `CZH-660`, `CZH-661`, `CZH-662`, `CZH-663`, `CZH-664`, `CZH-665`, `CZH-666`, `CZH-667`, `CZH-668`, `CZH-669`, `CZH-670`, `CZH-671`, `CZH-672`, `CZH-673`, `CZH-674`, `CZH-675`, `CZH-676`, `CZH-677`, `CZH-678`, `CZH-679`, `CZH-680`, `CZH-681`, `CZH-682`, `CZH-683`, `CZH-684`, `CZH-685`, `CZH-686`, `CZH-687`, `CZH-688`, `CZH-689`, `CZH-690`, `CZH-691`, `CZH-692`, `CZH-693`, `CZH-694`, `CZH-695`, `CZH-696`, `CZH-697`, `CZH-698`, `CZH-699`, `CZH-700`, `CZH-701`, `CZH-702`, `CZH-703`, `CZH-704`, `CZH-705`, `CZH-706`, `CZH-707`, `CZH-708`, `CZH-709`, `CZH-710`, `CZH-711`, `CZH-712`, `CZH-713`, `CZH-714`, `CZH-715`, `CZH-716`, `CZH-717`, `CZH-718`, `CZH-719`, `CZH-720`, `CZH-721`, `CZH-722`, `CZH-723`, `CZH-724`, `CZH-725`, `CZH-726`, `CZH-727`, `CZH-728`, `CZH-729`, `CZH-730`, `CZH-731`, `CZH-732`, `CZH-733`, `CZH-734`, `CZH-735`, `CZH-736`, `CZH-737`, `CZH-738`, `CZH-739`, `CZH-740`, `CZH-741`, `CZH-742`, `CZH-743`, `CZH-744`, `CZH-745`, `CZH-746`, `CZH-747`, `CZH-748`, `CZH-749`, `CZH-750`, `CZH-751`, `CZH-752`, `CZH-753`, `CZH-754`, `CZH-755`, `CZH-756`, `CZH-757`, `CZH-758`, `CZH-759`, `CZH-760`, `CZH-761`, `CZH-762`, `CZH-763`, `CZH-764`, `CZH-765`, `CZH-766`, `CZH-767`, `CZH-768`, `CZH-769`, `CZH-770`, `CZH-771`, `CZH-772`, `CZH-773`, `CZH-774`, `CZH-775`, `CZH-776`, `CZH-777`, `CZH-778`, `CZH-779`, `CZH-780`, `CZH-781`, `CZH-782`, `CZH-783`, `CZH-784`, `CZH-785`, `CZH-786`, `CZH-787`, `CZH-788`, `CZH-789`, `CZH-790`
