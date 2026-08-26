# Исследование Classic 0.9.12 и TFAR Arrowhead

Дата фиксации состояния upstream: 26 августа 2026 года.

## Базовые версии

- **Classic**: тег [`0.9.12`](https://github.com/michail-nikolaev/task-force-arma-3-radio/tree/fe9f54de0d7e30787592bd51125488b80ef34e07), commit `fe9f54de`.
- **Arrowhead**: текущая ветка [`master`](https://github.com/michail-nikolaev/task-force-arma-3-radio/tree/d76d8b32a1112c7c021c23dabef4654a593cc83a), commit `d76d8b32`.

Arrowhead — не отдельный репозиторий, а современное состояние того же upstream после `0.9.12`. Поэтому исходники и историю можно сравнивать напрямую, но современный плагин нельзя считать готовой заменой Classic: вместе с новыми функциями в нём заметно изменились маршрутизация голоса, пространственный звук и радио-DSP.

## Короткий вывод

Главное ограничение проекта: **сохраняем звук и привычный UX Classic, а поведение Arrowhead переносим небольшими изолированными частями**. Полный перенос современного `ts/src` слишком рискован и почти наверняка изменит звук.

| Подсистема | Что есть в Classic | Что есть в Arrowhead | Решение для Classic Dev |
| --- | --- | --- | --- |
| Zeus remote control | Есть `TFAR_currentUnit`, но смена тела обрабатывается нестабильно | Нормальный lifecycle смены юнита, сброс tangent и кэшей; остаётся баг с LR игрока | Перенести lifecycle, но не объединять TX-рации исходного и управляемого юнита |
| Слух из камеры Zeus | В основном реализован перемещением служебного тела | Настройка `TFAR_curatorCamEars`, аналогично для Splendid Camera | Перенести как выключенную по умолчанию клиентскую опцию |
| Выборочное общение Zeus | Нет | Нет; upstream обсуждает только общий переключатель точки слуха | Проектировать отдельно: один toggle, текущее выделение, без новых PTT-кнопок |
| Голос в транспорте | Старый `isTurnedOut`, простая строка vehicle ID | Существенно более точное определение места, FFV, турелей и изоляции | Перенести классификацию и формат descriptor, оставить DSP Classic |
| Наблюдатели и мёртвые | Почти полностью отрезаны | Камера spectator, фильтр врагов/союзников, чат наблюдателей | Перенести с обязательной серверной политикой для TvT/PvP |
| Защита радиосети | Частота и скрытый radio code сравниваются одной строкой | То же, плюс готовая настройка отключения кодов и API смены кода | Разделить частоту, waveform и код; добавить режим миссии `Legacy/Open/Keyed` |
| Talk Groups | Нет | Нет; есть только открытый запрос на selective squelch | Реализовать отдельно как поле канала `TG 0..9`, без Monitor в MVP |
| Рюкзак радиста | Игрок использует только свои/транспортные LR | Backend внешней LR существует, но UX и блокировки не закончены | Использовать backend как основу для TX через рюкзак радиста; RX оставить радисту |
| Аудиотракт | Привычный звук Classic | Другой порядок эффектов, фильтры, attenuation и 3D-панорама | Не переносить целиком; любые изменения проверять A/B |

Рекомендуемая первая задача после исследования — [#5](https://github.com/Ferraronp/tfar-classic-dev/issues/5). Она даёт заметный результат, почти не требует нового протокола и не затрагивает DSP.

## 1. Zeus и remote control

### Что уже сделано upstream

В Classic уже есть [`TFAR_fnc_currentUnit`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/fe9f54de0d7e30787592bd51125488b80ef34e07/arma3/%40task_force_radio/addons/task_force_radio/functions/fn_currentUnit.sqf) и подмена контролируемого юнита при расчёте позиций. Проблема не в отсутствии понятия current unit, а в неполном жизненном цикле смены тела и кэшей. Это соответствует старому багу [#1185](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1185): голос Zeus при remote control прыгал между исходным телом и управляемым юнитом.

Arrowhead исправляет основу через player event `unit` в [`fnc_ClientInit.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_ClientInit.sqf):

- публикует `TFAR_controlledUnit`, чтобы остальные клиенты знали реальный источник;
- отпускает зажатые tangent до и после смены юнита;
- меняет `TFAR_currentUnit` в одном месте;
- инвалидирует кэш loadout и список радиостанций;
- в [`fnc_processPlayerPositions.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_processPlayerPositions.sqf) подставляет контролируемого юнита вместо тела куратора.

Эта схема подтверждена как исправление #1185, но переносить её вслепую нельзя. В актуальном Arrowhead остаётся открытый баг [#1574](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1574): если исходное тело игрока имеет LR, передача при remote control может уйти через него, а не через LR управляемого юнита. Причина видна в [`fnc_lrRadiosList.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_lrRadiosList.sqf): список раций управляемого юнита дополняется рациями исходного игрока.

### Решение для #5

При активном remote control:

1. Источник локального голоса и слуха — управляемый юнит.
2. Активные TX-рации — только рации управляемого юнита.
3. При входе и выходе отпускаются все tangent, затем пересчитываются активные SR/LR.
4. Радио исходного тела не добавляется в список передачи. Возможность отдельно слушать его можно обсуждать позже, но она не должна неявно влиять на TX.
5. При уничтожении/потере управляемого юнита состояние атомарно возвращается к `player`.

Для первого варианта новый протокол Arma ↔ плагин не нужен: Classic уже отправляет позицию и рации `TFAR_currentUnit`. Нужны аккуратный перенос lifecycle и тесты переходов.

### Камера Zeus

Arrowhead умеет слушать из позиции камеры через [`fnc_onCuratorInterface.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/events/fnc_onCuratorInterface.sqf) и настройку `TFAR_curatorCamEars`. Аналогичная поддержка Splendid Camera добавлена в [PR #1538](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/1538). История запросов: [#1255](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1255), [#1270](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1270), [#1503](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1503).

Для Classic Dev стоит перенести режим «уши в камере» как клиентскую настройку, выключенную по умолчанию. Remote control имеет приоритет: пока Zeus управляет юнитом, и говорит, и слышит он от юнита, а не от камеры.

### Выборочное общение Zeus

Готовой реализации в Arrowhead нет. [#1270](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1270) предлагает только переключать слух между телом игрока, камерой Zeus или обеими точками; вопрос места, откуда Zeus говорит, там остаётся нерешённым.

Предлагаемый UX для [#6](https://github.com/Ferraronp/tfar-classic-dev/issues/6):

- одна новая кнопка-toggle только для Zeus;
- по умолчанию режим выключен;
- при включении Zeus слышит **текущее** выделение; при изменении выделения набор автоматически меняется;
- обычные кнопки TFAR не меняются: локальный PTT TeamSpeak остаётся способом говорить;
- выделенные игроки слышат обращение Zeus независимо от расстояния;
- если камера находится рядом без выделения, работает обычный позиционный голос из камеры;
- при remote control выборочный режим временно не влияет на источник голоса: действует управляемый юнит.

Для направления «Zeus слышит выделенных» локальный Arma-клиент может добавить флаг к POS-записи каждого выделенного игрока. Для обратного направления «выделенный игрок слышит Zeus» состояние адресатов нужно реплицировать через Arma и передать в локальные плагины адресатов. Одной подмены координаты камеры недостаточно: она описывает только одну точку и не умеет выразить список слушателей.

Отдельный флаг должен разрешать обращение Zeus даже при обычном `canSpeak == false`/оглушении адресата. Это специальное административное исключение, а не глобальное отключение механики оглушения. Дальний выборочный голос лучше подавать по центру без искусственного направления; голос из реально близкой камеры остаётся позиционным.

## 2. Голос в транспорте и turned out

### Почему баг можно исправить

Classic кодирует транспорт одной строкой вида `netId_turnout` или `netId_<isolation>` в [`fn_vehicleId.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/fe9f54de0d7e30787592bd51125488b80ef34e07/arma3/%40task_force_radio/addons/task_force_radio/functions/fn_vehicleId.sqf). Старый [`fn_isTurnedOut.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/fe9f54de0d7e30787592bd51125488b80ef34e07/arma3/%40task_force_radio/addons/task_force_radio/functions/fn_isTurnedOut.sqf) вручную обходит турели и animation sources. Он легко ошибается на FFV-местах, дополнительных турелях, cargo и модовой технике. Это наиболее вероятная причина ситуации «выглянул, но иногда никого не слышу».

Arrowhead значительно расширил [`fnc_isTurnedOut.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_isTurnedOut.sqf):

- использует нативный `isTurnedOut`;
- проверяет `fullCrew`, роль и turret path;
- учитывает FFV/cargo и `soundAttenuationCargo`;
- поддерживает конфигурацию `CBA_attenuatedRoles` для модовой техники;
- возвращает пару `[turnedOut, isolation]`;
- при включённой экспериментальной настройке читает attenuation из `CfgSoundEffects`.

Современный [`fnc_vehicleId.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_vehicleId.sqf) передаёт четыре поля: ID транспорта, turnout/isolation, intercom slot и velocity. Upstream-проблемы и история: [#362](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/362), [#521](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/521), [PR #578](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/578), [#536](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/536), открытый [#1130](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1130).

### Решение для #7

Переносить нужно **определение места и descriptor**, но не аудиообработку Arrowhead:

1. Портировать современную классификацию seat/turned-out/isolation без intercom-зависимостей.
2. Ввести versioned vehicle descriptor и parser с поддержкой старой строки.
3. Сохранить фильтры и формулу vehicle attenuation Classic на первом этапе.
4. Добавить диагностическую запись исходных данных, чтобы баг можно было привязать к конкретному месту и конфигу.

Минимальная матрица ручного теста:

| Ситуация | Направления проверки |
| --- | --- |
| Оба пешком | A → B и B → A |
| Оба внутри одной закрытой машины | Между всеми ролями |
| Один внутри, другой снаружи | Оба направления |
| Командир/стрелок turned in ↔ turned out | Оба состояния и переход во время речи |
| FFV/cargo | Внутри ↔ снаружи и между местами |
| Открытый автомобиль | Проверить отсутствие ложной полной изоляции |
| Закрытый APC/танк | Проверить ожидаемую сильную изоляцию |
| Модовая техника | С `CBA_attenuatedRoles` и без неё |

В лог теста нужны `typeOf`, роль из `fullCrew`, turret path, результат `isTurnedOut`, isolation и строка descriptor на обоих клиентах.

## 3. Наблюдатели, мёртвые и PvP

Classic в основном исключает мёртвого игрока из `getNearPlayers`; исправление [#1048](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1048) отдельно закрыло утечку голоса Zeus к мёртвым перед релизом 0.9.12.

Arrowhead переписал spectator в commit [`7bd84b38`](https://github.com/michail-nikolaev/task-force-arma-3-radio/commit/7bd84b388c56752d8f06f164484f50e152adc568) по [#1151](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1151):

- наблюдатель слышит живых вокруг своей spectator-камеры;
- врагов и союзников можно фильтровать отдельно;
- наблюдатели слышат друг друга непозиционно;
- живые не слышат наблюдателей;
- радиопередача для наблюдателей выключена.

Позже появились отдельный mute наблюдателей ([PR #1567](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/1567)), запрос на listen-only radio [#1176](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1176), запрос «слышать живых, но заглушить наблюдателей» [#1375](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1375) и проблема слишком громкого spectator-чата [#1525](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1525).

### Решение для #11

Клиентская галочка недостаточна для TvT: игрок может включить себе запрещённое прослушивание. Нужна глобальная настройка миссии, принудительно применяемая сервером:

- `Disabled` — наблюдатели не слышат живых;
- `Friendlies` — слышат только союзников около камеры;
- `Everyone` — слышат всех около камеры.

Безопасное значение по умолчанию для PvP-пресета — `Disabled`. Чат между наблюдателями настраивается отдельно и никогда не слышен живым. Радиопередача наблюдателя всегда запрещена. Listen-only radio лучше делать отдельным этапом: это требует сформировать RX-состояние радио при жёстко отключённом TX.

Громкость непозиционного spectator-чата нельзя оставлять равной чистому TeamSpeak: либо нормализовать её относительно локальной речи, либо добавить отдельный client volume после серверной проверки прав.

## 4. Радиосовместимость и защита сети

### Как устроено сейчас

И Classic, и Arrowhead сравнивают не только частоту. SQF склеивает частоту и radio code в одну непрозрачную строку, например `100.0_bluefor`, а плагин проверяет точное равенство. Это подтверждено разработчиком в [#1171](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1171). API изменения кода отдельной SR/LR-рации существует со старого [PR #401](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/401).

Arrowhead дополнительно имеет глобальную CBA-настройку `TFAR_radioCodesDisabled`: при её включении [`fnc_getSwRadioCode.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_getSwRadioCode.sqf) и LR-аналог возвращают пустой код. Это уже готовая основа для пользовательского режима «без шифрования».

### Что реалистично

Две разные модели реальных раций могут связаться, если совпадают диапазон, частота, тип модуляции/waveform, шаг канала и настройки squelch/защиты. Совпадение корпуса или classname не требуется. И наоборот, одинаковая частота не поможет, если одна станция использует несовместимый waveform, hopping или другой ключ.

Текущий `radio code` TFAR — не криптография и не симуляция ключевого материала. Это метка совместимости. Поэтому правильнее перестать неявно привязывать её к типу/стороне рации и представить радиоидентичность структурно:

```text
waveform + frequency + protectionCode + talkGroup
```

Предлагаемые режимы миссии для [#9](https://github.com/Ferraronp/tfar-classic-dev/issues/9):

- `Legacy` — текущее поведение Classic для старых миссий;
- `Open` — protection code игнорируется, совместимость определяется waveform и частотой;
- `Keyed` — код хранится в настройках конкретной рации, отображается/копируется и не зависит от её модели.

В `Keyed` захваченная рация сохраняет все настройки. Игрок может прочитать её код и настроить совместимую собственную рацию так же. Это соответствует желаемой логике захвата и не требует физически дублировать тот же classname. Миссия может полностью запретить редактирование или отключить коды.

Для MVP код может быть трёхзначным, но в протоколе его лучше хранить строкой: это оставляет ведущие нули и не мешает будущим пресетам.

## 5. Talk Groups

Готовых Talk Groups в Arrowhead нет. Ближайший upstream-запрос — открытый [#1443](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1443) про selective squelch: отдельный TX-код и список разрешённых RX-кодов на одной частоте. Текущий additional channel умеет слушать/передавать только вторую пару «частота + тот же radio code».

MVP для [#10](https://github.com/Ferraronp/tfar-classic-dev/issues/10):

```text
CH1: 100.0 / TG 0
CH2: 100.0 / TG 1
CH3: 167.2 / TG 5
```

- TG хранится отдельно для каждого канала, допустимые значения `0..9`;
- новым группам назначается обычная частота и `TG 0`;
- переключение каналов на numpad не меняется;
- additional channel и `T` работают как сейчас, но используют TG выбранного дополнительного канала;
- интерфейс частоты не превращается в ввод `xxx.x.x`: TG показывается отдельным полем;
- режима Monitor в MVP нет.

Для игрового MVP приём совпадает по `waveform + frequency + protectionCode + TG`. В реальном аналоговом радио CTCSS/DCS лишь открывает squelch и не создаёт независимый эфир: одновременные передачи на одной частоте всё равно конфликтуют. Наш TG — упрощённая логическая группировка, ближе к цифровым сетям. Если позже понадобится RF-реализм, radio config сможет объявлять `analog` или `digital` waveform и разные правила коллизий.

Talk Groups зависят от решения #9 и новой версии протокола. Подделывать TG ещё одной цифрой в строке частоты не стоит: это осложнит сравнение, UI и совместимость.

## 6. Рюкзак радиста и внешняя LR

Arrowhead имеет незавершённый backend `TFAR_OverrideActiveLRRadio`: [`fnc_activeLrRadio.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/addons/core/functions/fnc_activeLrRadio.sqf) проверяет расстояние до внешней рации, а поддержка списка LR добавлена в [PR #1445](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/1445). В [#1502](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1502) разработчик прямо пишет, что backend существует, но не закончены тестирование, ACE interactions, настройки внешнего пользователя и защита от одновременного доступа.

Static radios [#1342](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1342) и система антенн из [#603](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/603) решают другие задачи: размещённая радиостанция и покрытие/relay, а не взаимодействие командира с живым радистом.

Предлагаемый MVP для [#8](https://github.com/Ferraronp/tfar-classic-dev/issues/8):

1. Радист несёт отдельный LR-рюкзак и остаётся единственным получателем входящих сообщений.
2. Разрешённый игрок рядом может через ACE-действие взять гарнитуру/тангенту.
3. Его исходящая передача использует активный канал, TG и код рюкзака радиста.
4. Исходящий голос не нужно пересказывать; входящий радист по-прежнему пересказывает лично.
5. Доступ прекращается при отходе, смерти, потере рюкзака, смене владельца или remote control.
6. В один момент внешним TX-пользователем может быть только один игрок; радист явно разрешает доступ либо миссия задаёт доверенную роль.

Это намеренно уже, чем полноценная «общая рация». Оно совпадает с желаемым игровым процессом и не требует сразу микшировать входящий звук нескольким владельцам. Backend Arrowhead можно использовать как основу, но его правила владения и конкуренции нужно дописать.

## 7. Почему нельзя переносить аудиоплагин целиком

Разница звука между Classic и Arrowhead реальна на уровне кода, хотя оценка «лучше/хуже» остаётся субъективной.

| Участок | Classic 0.9.12 | Arrowhead |
| --- | --- | --- |
| Порядок radio effect | delay → ring modulation → foldback → HP/LP → усиление ×30 | foldback → усиление ×30 внутри delay/ring modulation → HP/LP |
| Error curve | Интерполяция использует `(from - to)` | Направление исправлено на `(to - from)` и индекс ограничен |
| SR-фильтры | Speaker 520–4300 Гц плюс Mic 900–3000 Гц | Один каскад 900–3000 Гц |
| Airborne | Использует LR-effect 520–1300 Гц | Отдельный effect 1000–4000 Гц |
| Локальная громкость | Ручная степенная формула `d^-0.3` и линейный остаток | Экспоненциальная NaturalSound-кривая |
| Пространственный звук | Собственные clunk/ILD | X3DAudio, distance curve и опциональный voice cone |
| Дополнительные эффекты | Монолитный pipeline | Object interception, antennas, SampleBuffer, отдельные handlers |

Исходники: [`RadioEffect.h` Classic](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/fe9f54de0d7e30787592bd51125488b80ef34e07/ts/src/RadioEffect.h), [`RadioEffect.hpp` Arrowhead](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/ts/src/RadioEffect.hpp), [`plugin.cpp` Classic](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/fe9f54de0d7e30787592bd51125488b80ef34e07/ts/src/plugin.cpp), [`plugin.cpp` Arrowhead](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/ts/src/plugin.cpp), [`helpers.hpp` Arrowhead](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/d76d8b32a1112c7c021c23dabef4654a593cc83a/ts/src/helpers.hpp). Большая часть изменения radio effect оформлена commit [`79983b6b`](https://github.com/michail-nikolaev/task-force-arma-3-radio/commit/79983b6bd1b81ff9d651ee7ca4dea3e7302444ad).

Решение:

- сохранить DSP, rolloff и панораму Classic как baseline;
- не переносить `clientData/serverData/PlaybackHandler` целиком;
- расширять только parser, routing flags и диагностику;
- любые будущие изменения звука делать отдельной задачей с переключаемым preset;
- подготовить A/B fixtures: чистый/слабый SR, LR, airborne, direct voice на нескольких расстояниях и через транспорт;
- сравнивать peak, RMS, спектр и субъективный blind test.

## 8. Протокол Arma ↔ TeamSpeak

TeamSpeak Plugin API 26 и внутренний протокол TFAR — разные вещи. Поддержка API 26 не версионирует строки `POS`/`FREQ`.

Classic отправляет 13 позиционных полей в [`fn_preparePositionCoordinates.sqf`](https://github.com/michail-nikolaev/task-force-arma-3-radio/blob/fe9f54de0d7e30787592bd51125488b80ef34e07/arma3/%40task_force_radio/addons/task_force_radio/functions/fn_preparePositionCoordinates.sqf). Arrowhead тоже использует 13 полей, но их смысл уже другой: добавлены object interception, spectator и enemy flags, изменены position/view direction и vehicle descriptor. Простое совпадение количества полей не означает совместимость.

Перед первой несовместимой фичей нужен явный номер protocol/capabilities. Плагин должен:

- понимать старые `POS`/`FREQ` Classic;
- принимать новую версию с именованным набором capabilities;
- отклонять неизвестную несовместимую версию с понятной ошибкой;
- не использовать TeamSpeak API version как версию протокола TFAR.

| Задача | Новые данные протокола |
| --- | --- |
| #5 remote control | Не обязательны |
| #7 транспорт | Versioned vehicle descriptor |
| #11 spectator | `isSpectator`, relation/policy result |
| #9 защита | Отдельные `waveform` и `protectionCode` |
| #10 TG | `talkGroup` у каждой активной записи канала |
| #6 selective Zeus | Флаг принудительного direct RX и режим позиционирования |
| #8 TX через радиста | Для MVP не обязательны; позже может понадобиться позиция внешней антенны |

## 9. Диагностика

Логи стоит добавлять вместе с первым расширением routing, а не после появления трудноуловимых багов. Нужен компактный ring buffer с reason codes, который выгружается по команде, но не спамит обычный лог.

Минимальные события:

- смена `TFAR_currentUnit`, начало/конец remote control, сброс tangent;
- решение direct voice: расстояние, `canSpeak`, spectator/Zeus override, итоговый route/mute;
- vehicle descriptor обоих участников и применённая isolation;
- radio route: waveform, frequency, code, TG, radio ID, причина match/reject;
- смена spectator policy;
- версия и capabilities протокола;
- предупреждение о старом addon/plugin вместо тихого несовпадения.

Ники и Steam UID в публичный debug bundle лучше не писать без отдельного согласия; достаточно временных client IDs и хешированных radio IDs.

## 10. Порядок реализации

1. **[#5 — remote control](https://github.com/Ferraronp/tfar-classic-dev/issues/5).** Перенести lifecycle Arrowhead, исправив выбор TX-раций.
2. **[#7 — транспорт](https://github.com/Ferraronp/tfar-classic-dev/issues/7).** Сначала воспроизводимый тест и логи, затем новый seat/turned-out descriptor без смены DSP.
3. **Основа protocol/capabilities и ring-buffer диагностика.** Нужна до следующих маршрутов.
4. **[#11 — spectator](https://github.com/Ferraronp/tfar-classic-dev/issues/11).** Серверные режимы `Disabled/Friendlies/Everyone`, без TX.
5. **[#9 — radio identity и защита](https://github.com/Ferraronp/tfar-classic-dev/issues/9).** Режимы `Legacy/Open/Keyed`, waveform и захватываемые настройки.
6. **[#10 — Talk Groups](https://github.com/Ferraronp/tfar-classic-dev/issues/10).** TG `0..9` как отдельное поле канала, без Monitor.
7. **[#6 — selective Zeus](https://github.com/Ferraronp/tfar-classic-dev/issues/6).** Один toggle, динамическое выделение, отдельный bypass оглушения только для адресного Zeus-голоса.
8. **[#8 — рюкзак радиста](https://github.com/Ferraronp/tfar-classic-dev/issues/8).** Внешний TX через LR радиста с ACE interaction и эксклюзивным доступом.

Такой порядок сначала закрывает хорошо изученные баги с минимальным риском, затем вводит versioned protocol, после чего можно безопасно добавлять новые маршруты голоса и радио.

## Критерии, которые должны оставаться инвариантами

- Стандартные клавиши Classic не меняются без явной настройки.
- Новые режимы Zeus не добавляют отдельные SR/LR PTT.
- Remote control всегда имеет однозначный источник голоса и TX.
- PvP-ограничения задаёт миссия/сервер, а не сам наблюдатель.
- Радиосовместимость не определяется одним classname.
- Захваченная рация сохраняет читаемые настройки в режиме `Keyed`.
- `TG` не маскируется под дробную часть частоты.
- Ни одна функциональная миграция не должна неявно менять DSP Classic.

## Основные upstream-ссылки

- Zeus: [#1185](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1185), [#1255](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1255), [#1270](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1270), [#1503](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1503), [#1574](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1574), [PR #1538](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/1538).
- Транспорт: [#362](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/362), [#521](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/521), [#536](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/536), [#1130](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1130), [PR #578](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/578).
- Spectator: [#1048](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1048), [#1151](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1151), [#1176](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1176), [#1375](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1375), [#1525](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1525), [PR #1567](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/1567).
- Радио/TG: [#1171](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1171), [#1443](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1443), [PR #401](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/401).
- Радист/антенны: [#603](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/603), [#923](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/923), [#1342](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1342), [#1502](https://github.com/michail-nikolaev/task-force-arma-3-radio/issues/1502), [PR #1445](https://github.com/michail-nikolaev/task-force-arma-3-radio/pull/1445).