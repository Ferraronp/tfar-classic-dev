# TFAR Classic Fixes

Эта ветка собирает **отдельный сабмод** для оригинального TFAR Classic 0.9.12:
голос Zeus от управляемого юнита, корректное переключение позиции и раций.

Установка: **CBA_A3 + оригинальный TFAR Classic 0.9.12 + @tfar_classic_fixes**
у всех игроков. Заменять оригинальный task_force_radio.pbo не требуется.

**[Установка, зависимости и ручная проверка](submod/README.md)**

~~~sh
python scripts/build-submod.py
~~~

Нужны Python 3.10+ и HEMTT. Готовый архив — dist/submod/tfar-classic-fixes.zip.
Workflow classic-fixes-submod.yml собирает и подписывает только PBO сабмода,
без LFS и без сборки TS-плагина.

Совместимость с TS3 3.6.x обеспечивается отдельным TFAR plugin API 26:
он не входит в сабмод. Инструкция сборки плагина — [BUILDING.md](BUILDING.md).

Исходники оригинального/полного TFAR в arma3/ и ts/ сохранены для истории,
но не используются при сборке сабмода.

Неофициальный производный проект. Оригинальный TFAR: Michail Nikolaev (NKey),
L-H и TFAR contributors. Лицензия APL-SA:
[LICENSE](submod/LICENSE.md), [авторы и происхождение изменений](submod/AUTHORS.md).
