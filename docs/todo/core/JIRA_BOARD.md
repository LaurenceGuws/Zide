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

- Sprint ID: `CZH-S66` (review_gate at CZH-GATE-125)
- Previous Sprint: `CZH-S65` (accepted)
- Super-gate: `CZH-GATE-125` (enforcement evidence surface normalization)

## Ticket Order (`CZH-S66`)

1. `CZH-1173`
2. `CZH-1174`
3. `CZH-1175`
4. `CZH-1176`
5. `CZH-1177`
6. `CZH-1178`
7. `CZH-1179`
8. `CZH-1180`

## Current State

- `in_progress`: none
- `todo`: none
- `review_gate`: `CZH-1173`, `CZH-1174`, `CZH-1175`, `CZH-1176`, `CZH-1177`, `CZH-1178`, `CZH-1179`, `CZH-1180` (CZH-S66, in_progress)
- `blocked`: none
- `changes_required`: `CZH-B35` at `CZH-GATE-89`
- `done`: `CZH-901`, `CZH-902`, `CZH-903`, `CZH-904`, `CZH-905`, `CZH-906`, `CZH-907`, `CZH-908`, `CZH-909`, `CZH-910`, `CZH-911`, `CZH-912`, `CZH-913`, `CZH-914`, `CZH-915`, `CZH-916`, `CZH-917`, `CZH-918`, `CZH-919`, `CZH-920`, `CZH-921`, `CZH-922`, `CZH-923`, `CZH-924`, `CZH-925`, `CZH-926`, `CZH-927`, `CZH-928`, `CZH-929`, `CZH-930`, `CZH-931`, `CZH-932`, `CZH-933`, `CZH-934`, `CZH-935`, `CZH-936`, `CZH-937`, `CZH-938`, `CZH-939`, `CZH-940`, `CZH-951`, `CZH-952`, `CZH-953`, `CZH-954`, `CZH-955`, `CZH-956`, `CZH-957`, `CZH-958`, `CZH-959`, `CZH-960`, `CZH-961`, `CZH-962`, `CZH-963`, `CZH-964`, `CZH-965`, `CZH-966`, `CZH-967`, `CZH-968`, `CZH-969`, `CZH-970`, `CZH-971`, `CZH-972`, `CZH-973`, `CZH-974`, `CZH-975`, `CZH-976`, `CZH-977`, `CZH-978`, `CZH-979`, `CZH-980`, `CZH-981`, `CZH-982`, `CZH-983`, `CZH-984`, `CZH-985`, `CZH-986`, `CZH-987`, `CZH-988`, `CZH-989`, `CZH-990`, `CZH-991`, `CZH-992`, `CZH-993`, `CZH-994`, `CZH-995`, `CZH-996`, `CZH-997`, `CZH-998`, `CZH-999`, `CZH-1000`, `CZH-1001`, `CZH-1002`, `CZH-1003`, `CZH-1004`, `CZH-1005`, `CZH-1006`, `CZH-1007`, `CZH-1008`, `CZH-1009`, `CZH-1010`, `CZH-1011`, `CZH-1012`, `CZH-1013`, `CZH-1014`, `CZH-1015`, `CZH-1016`, `CZH-1017`, `CZH-1018`, `CZH-1019`, `CZH-1020`, `CZH-1021`, `CZH-1022`, `CZH-1023`, `CZH-1024`, `CZH-1025`, `CZH-1026`, `CZH-1027`, `CZH-1028`, `CZH-1029`, `CZH-1030`, `CZH-1031`, `CZH-1032`, `CZH-1033`, `CZH-1034`, `CZH-1035`, `CZH-1036`, `CZH-1037`, `CZH-1038`, `CZH-1039`, `CZH-1040`, `CZH-1041`, `CZH-1042`, `CZH-1043`, `CZH-1044`, `CZH-1045`, `CZH-1046`, `CZH-1047`, `CZH-1048`, `CZH-1049`, `CZH-1050`, `CZH-1051`, `CZH-1052`, `CZH-1053`, `CZH-1054`, `CZH-1055`, `CZH-1056`, `CZH-1057`, `CZH-1058`, `CZH-1059`, `CZH-1060`, `CZH-1061`, `CZH-1062`, `CZH-1063`, `CZH-1064`, `CZH-1065`, `CZH-1066`, `CZH-1067`, `CZH-1068`, `CZH-1069`, `CZH-1070`, `CZH-1071`, `CZH-1072`, `CZH-1073`, `CZH-1074`, `CZH-1075`, `CZH-1076`, `CZH-1077`, `CZH-1078`, `CZH-1079`, `CZH-1080`, `CZH-1081`, `CZH-1082`, `CZH-1083`, `CZH-1084`, `CZH-1085`, `CZH-1086`, `CZH-1087`, `CZH-1088`, `CZH-1089`, `CZH-1090`, `CZH-1091`, `CZH-1092`, `CZH-1093`, `CZH-1094`, `CZH-1095`, `CZH-1096`, `CZH-1097`, `CZH-1098`, `CZH-1099`, `CZH-1100`, `CZH-1101`, `CZH-1102`, `CZH-1103`, `CZH-1104`, `CZH-1105`, `CZH-1106`, `CZH-1107`, `CZH-1108`, `CZH-1109`, `CZH-1110`, `CZH-1111`, `CZH-1112`, `CZH-1113`, `CZH-1114`, `CZH-1115`, `CZH-1116`, `CZH-1117`, `CZH-1118`, `CZH-1119`, `CZH-1120`, `CZH-1121`, `CZH-1122`, `CZH-1123`, `CZH-1124`, `CZH-1125`, `CZH-1126`, `CZH-1127`, `CZH-1128`, `CZH-1129`, `CZH-1130`, `CZH-1131`, `CZH-1132`, `CZH-1133`, `CZH-1134`, `CZH-1135`, `CZH-1136`, `CZH-1137`, `CZH-1138`, `CZH-1139`, `CZH-1140`, `CZH-B1`, `CZH-B2`, `CZH-B3`, `CZH-B4`, `CZH-B5` (accepted as a narrow hygiene slice), `CZH-B6` (accepted), `CZH-B7` (accepted), `CZH-B8` (accepted), `CZH-B9` (accepted), `CZH-B10` (accepted), `CZH-B11` (accepted), `CZH-B12` (accepted), `CZH-B13` (accepted), `CZH-B14` (accepted), `CZH-B15` (accepted), `CZH-B16` (accepted), `CZH-B17` (accepted), `CZH-B18` (accepted), `CZH-B19` (accepted), `CZH-B20` (accepted), `CZH-B21` (accepted), `CZH-B22` (accepted), `CZH-B23` (accepted), `CZH-B24` (accepted), `CZH-B25` (accepted), `CZH-B26` (accepted), `CZH-B27` (accepted), `CZH-B28` (accepted), `CZH-B29` (accepted), `CZH-B30` (accepted), `CZH-B31` (accepted), `CZH-B32` (accepted), `CZH-B33` (accepted), `CZH-B34` (accepted), `CZH-B36` (accepted), `CZH-B37` (accepted), `CZH-B38` (accepted), `CZH-B39` (accepted), `CZH-B40` (accepted), `CZH-B41` (accepted), `CZH-B42` (accepted), `CZH-B43` (accepted), `CZH-B44` (accepted), `CZH-B45` (accepted), `CZH-B46` (accepted), `CZH-B47` (accepted), `CZH-B48` (accepted), `CZH-B49` (accepted), `CZH-B50` (accepted), `CZH-B51` (accepted), `CZH-B52` (accepted), `CZH-B53` (accepted), `CZH-B54` (accepted), `CZH-B55` (accepted), `CZH-B56` (accepted), `CZH-B57` (accepted), `CZH-B58` (accepted), `CZH-B59` (accepted), `CZH-B60` (accepted), `CZH-B61` (accepted), `CZH-B62` (accepted), `CZH-B63` (accepted), `CZH-B64` (accepted), `CZH-B65` (accepted), `CZH-B66` (accepted), `CZH-601`, `CZH-602`, `CZH-603`, `CZH-604`, `CZH-605`, `CZH-606`, `CZH-607`, `CZH-608`, `CZH-609`, `CZH-610`, `CZH-611`, `CZH-612`, `CZH-613`, `CZH-614`, `CZH-615`, `CZH-616`, `CZH-617`, `CZH-618`, `CZH-619`, `CZH-620`, `CZH-621`, `CZH-622`, `CZH-623`, `CZH-624`, `CZH-625`, `CZH-626`, `CZH-627`, `CZH-628`, `CZH-629`, `CZH-630`, `CZH-631`, `CZH-632`, `CZH-633`, `CZH-634`, `CZH-635`, `CZH-636`, `CZH-637`, `CZH-638`, `CZH-639`, `CZH-640`, `CZH-641`, `CZH-642`, `CZH-643`, `CZH-644`, `CZH-645`, `CZH-646`, `CZH-647`, `CZH-648`, `CZH-649`, `CZH-650`, `CZH-651`, `CZH-652`, `CZH-653`, `CZH-654`, `CZH-655`, `CZH-656`, `CZH-657`, `CZH-658`, `CZH-659`, `CZH-660`, `CZH-661`, `CZH-662`, `CZH-663`, `CZH-664`, `CZH-665`, `CZH-666`, `CZH-667`, `CZH-668`, `CZH-669`, `CZH-670`, `CZH-671`, `CZH-672`, `CZH-673`, `CZH-674`, `CZH-675`, `CZH-676`, `CZH-677`, `CZH-678`, `CZH-679`, `CZH-680`, `CZH-681`, `CZH-682`, `CZH-683`, `CZH-684`, `CZH-685`, `CZH-686`, `CZH-687`, `CZH-688`, `CZH-689`, `CZH-690`, `CZH-691`, `CZH-692`, `CZH-693`, `CZH-694`, `CZH-695`, `CZH-696`, `CZH-697`, `CZH-698`, `CZH-699`, `CZH-700`, `CZH-701`, `CZH-702`, `CZH-703`, `CZH-704`, `CZH-705`, `CZH-706`, `CZH-707`, `CZH-708`, `CZH-709`, `CZH-710`, `CZH-711`, `CZH-712`, `CZH-713`, `CZH-714`, `CZH-715`, `CZH-716`, `CZH-717`, `CZH-718`, `CZH-719`, `CZH-720`, `CZH-721`, `CZH-722`, `CZH-723`, `CZH-724`, `CZH-725`, `CZH-726`, `CZH-727`, `CZH-728`, `CZH-729`, `CZH-730`, `CZH-731`, `CZH-732`, `CZH-733`, `CZH-734`, `CZH-735`, `CZH-736`, `CZH-737`, `CZH-738`, `CZH-739`, `CZH-740`, `CZH-741`, `CZH-742`, `CZH-743`, `CZH-744`, `CZH-745`, `CZH-746`, `CZH-747`, `CZH-748`, `CZH-749`, `CZH-750`, `CZH-751`, `CZH-752`, `CZH-753`, `CZH-754`, `CZH-755`, `CZH-756`, `CZH-757`, `CZH-758`, `CZH-759`, `CZH-760`, `CZH-761`, `CZH-762`, `CZH-763`, `CZH-764`, `CZH-765`, `CZH-766`, `CZH-767`, `CZH-768`, `CZH-769`, `CZH-770`, `CZH-771`, `CZH-772`, `CZH-773`, `CZH-774`, `CZH-775`, `CZH-776`, `CZH-777`, `CZH-778`, `CZH-779`, `CZH-780`, `CZH-781`, `CZH-782`, `CZH-783`, `CZH-784`, `CZH-785`, `CZH-786`, `CZH-787`, `CZH-788`, `CZH-789`, `CZH-790`, `CZH-861`, `CZH-862`, `CZH-863`, `CZH-864`, `CZH-865`, `CZH-866`, `CZH-867`, `CZH-868`, `CZH-869`, `CZH-870`, `CZH-871`, `CZH-872`, `CZH-873`, `CZH-874`, `CZH-875`, `CZH-876`, `CZH-877`, `CZH-878`, `CZH-879`, `CZH-880`, `CZH-881`, `CZH-882`, `CZH-883`, `CZH-884`, `CZH-885`, `CZH-886`, `CZH-887`, `CZH-888`, `CZH-889`, `CZH-890`, `CZH-891`, `CZH-892`, `CZH-893`, `CZH-894`, `CZH-895`, `CZH-896`, `CZH-897`, `CZH-898`, `CZH-899`, `CZH-900`
