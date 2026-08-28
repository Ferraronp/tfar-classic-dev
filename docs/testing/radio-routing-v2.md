# Ручная проверка маршрутизации Open/Keyed

Эта проверка относится к issue #18. Она требует сборок из одной ревизии:

- игрового `task_force_radio.pbo`;
- TeamSpeak-плагина `task_force_radio_win32.dll`/`task_force_radio_win64.dll`.

Одной замены PBO или одной замены DLL недостаточно. В режимах `Open` и `Keyed`
несовместимый клиент не получает radio audio; обычный positional voice продолжает
работать.

## 1. Установка тестовых сборок

1. Скачать artifact `tfar-classic-game-*` из workflow «Сборка игрового аддона».
2. Наложить папку `@task_force_radio` из архива на TFAR Classic 0.9.12 с заменой
   `addons/task_force_radio.pbo` и его тестовой подписи. Остальные PBO и
   `task_force_radio_pipe.dll` оставить от установленного TFAR 0.9.12.
3. Скачать artifact `tfar-classic-teamspeak-*` из workflow
   «Сборка TeamSpeak-плагина».
4. Полностью закрыть TeamSpeak, включая процесс в трее, и запустить
   `tfar-classic-api26.ts3_plugin`. Альтернатива — вручную заменить DLL в
   `%APPDATA%\TS3Client\plugins`.
5. Запустить TeamSpeak заново и убедиться, что плагин TFAR включён.
6. Повторить установку на каждом клиенте и на игровом сервере заменить PBO/ключ,
   если сервер проверяет подписи.

## 2. Тестовая миссия

Нужны два игрока в одном канале TeamSpeak. Для cross-side тестов разместить одного
за West, другого за East и выдать им SW-рации; для SW ↔ LR одному игроку также
нужна LR-рация или транспортная LR.

В `description.ext` разрешить debug console:

~~~sqf
enableDebugConsole = 1;
~~~

В `init.sqf` выбрать ровно один режим:

~~~sqf
TFAR_radioNetworkMode = "Open";
// TFAR_radioNetworkMode = "Keyed";
// TFAR_radioNetworkMode = "Legacy";
~~~

После изменения режима перезапускать миссию. Команды ниже выполнять через
`LOCAL EXEC` на соответствующем клиенте.

### Настроить активную SW-рацию

~~~sqf
private _radio = call TFAR_fnc_activeSwRadio;
[_radio, 0] call TFAR_fnc_setSwChannel;
[_radio, "50.0"] call TFAR_fnc_setSwFrequency;
[_radio, 0, "123"] call TFAR_fnc_setSwProtectionCode;
call TFAR_fnc_sendFrequencyInfo;
~~~

### Настроить активную LR-рацию

~~~sqf
private _radio = call TFAR_fnc_activeLrRadio;
[_radio select 0, _radio select 1, 0] call TFAR_fnc_setLrChannel;
[_radio select 0, _radio select 1, "50.0"] call TFAR_fnc_setLrFrequency;
[_radio, 0, "123"] call TFAR_fnc_setLrProtectionCode;
call TFAR_fnc_sendFrequencyInfo;
~~~

В `Open` записанный код всё равно нормализуется в `000`. В `Keyed` заменить
`123` на нужное значение отдельно на каждом клиенте.

## 3. Основная матрица

Перед каждым тестом оба игрока должны находиться в пределах обычной дальности
радио. Проверять передачу в обе стороны.

| Режим | Передатчик | Приёмник | Ожидается |
| --- | --- | --- | --- |
| Legacy | West SW, 50.0 | East SW, 50.0 | Не слышит: прежние side codes |
| Open | West SW, 50.0 | East SW, 50.0 | Слышит независимо от стороны/classname |
| Open | SW, 50.0 | LR, 50.0 | Слышит в обоих направлениях |
| Open | SW, 100.0 | LR, принудительно 100.0 | Не слышит: 100 МГц вне диапазона LR |
| Keyed | SW, 50.0, `123` | SW/LR, 50.0, `123` | Слышит |
| Keyed | SW, 50.0, `123` | SW/LR, 50.0, `124` | Не слышит |
| Keyed | SW, 50.0, `000` | SW/LR, 50.0, `000` | Слышит |
| Keyed | SW, 50.0, `000` | SW/LR, 50.0, `123` | Не слышит |
| Open/Keyed | Любой совместимый route | Другая частота | Не слышит |

Чтобы принудительно записать 100 МГц в LR для отрицательной проверки:

~~~sqf
private _radio = call TFAR_fnc_activeLrRadio;
[_radio, 1, "100.0"] call TFAR_fnc_SetChannelFrequency;
call TFAR_fnc_sendFrequencyInfo;
~~~

Маршрут LR будет отброшен проверкой диапазона, даже если старый dialog/settings
позволил сохранить такое значение.

## 4. Additional channel

На передающем SW-клиенте создать разные сети на основном и дополнительном
каналах:

~~~sqf
private _radio = call TFAR_fnc_activeSwRadio;
[_radio, 0] call TFAR_fnc_setSwChannel;
[_radio, 1, "50.0"] call TFAR_fnc_SetChannelFrequency;
[_radio, 2, "50.0"] call TFAR_fnc_SetChannelFrequency;
[_radio, 0, "124"] call TFAR_fnc_setSwProtectionCode;
[_radio, 1, "123"] call TFAR_fnc_setSwProtectionCode;
[_radio, 1] call TFAR_fnc_setAdditionalSwChannel;
call TFAR_fnc_sendFrequencyInfo;
~~~

Приёмник остаётся на `50.0`/`123`. Обычный SW PTT не должен быть слышен,
additional SW PTT должен быть слышен. Это подтверждает, что additional использует
код своего channel slot, а не код активного канала.

## 5. Speakers и совместимость версий

1. Включить speaker у SW или LR с совпадающим route: второй игрок рядом слышит
   радиопередачу из позиции speaker.
2. Изменить только NET code speaker-рации: в `Keyed` воспроизведение исчезает.
3. Вернуть тот же код: воспроизведение возвращается с прежней громкостью и
   панорамой.
4. На одном клиенте временно вернуть старую TeamSpeak DLL и запустить миссию в
   `Open`/`Keyed`: radio audio между совместимым и несовместимым клиентом не идёт.
   При попытке PTT новый addon один раз показывает подсказку об обновлении
   TeamSpeak-плагина. Direct voice рядом продолжает работать.

## 6. Что не должно измениться

- PTT-клавиши и обычные transmit/end hints;
- начало/конец radio sounds и DSP `digital`, `digital_lr`, `airborne`, `dd`;
- дальность, terrain attenuation, громкость и left/right stereo;
- поведение старых миссий, которые не задают `TFAR_radioNetworkMode` (`Legacy`).

Отдельного поля NET в radio dialog эта задача не добавляет: UI программирования
кода относится к следующему этапу. В этой сборке результат виден по фактической
слышимости и по fail-closed подсказке при несовместимом TeamSpeak-плагине.
