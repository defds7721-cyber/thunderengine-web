# ThunderEngine

ThunderEngine это порт CM1 r20.2 (Cloud Model 1) на браузеры: динамика CM1 и её основные схемы, посчитанные на видеокарте через WebGPU.

Сайт: https://defds7721-cyber.github.io/thunderengine-web/

(English version is at the end)

------------------------------------------------------------------

## Что он умеет

1. Запускать симуляции по заготовленным зондировкам либо по своим.
2. Работать на всех устройствах, которые поддерживают WebGPU. Вся модель считается на видеокарте прямо в браузере, ничего ставить не нужно.
3. Делать свои пресеты: все поля конфигурации CM1 в редакторе, с описанием каждого поля и проверкой, что сценарий соберётся.
4. Собирать зондировку руками: Skew-T и годограф, точки тянутся мышью или пальцем. Сразу видно CAPE, CIN, уровни конденсации, свободной конвекции и равновесия, сдвиг ветра и SRH.
5. Загружать готовое: файл `input_sounding` или `namelist.input` от CM1.
6. Делиться пресетом одной ссылкой, вместе с зондировкой.
7. Показывать грозу: срезы на любой высоте, вертикальный разрез, стрелки ветра, 3D, вид с земли.
8. Смотреть прошлые моменты прогона по шкале времени, не останавливая счёт.
9. Брать большие сетки, до 4 ГБ памяти (ураган, торнадо-сетка 100 м). Влезают, но считаются медленно.
10. Работать на русском и английском.

------------------------------------------------------------------

## Слои

1. Отражаемость (композит или на высоте)
2. Вертикальная скорость
3. Вихрь ζ
4. Облака
5. θ′
6. Ветер
7. Радиальная скорость от радара, точку радара можно ставить самому

В 3D: изоповерхности отражаемости, облака, дождь, град, восходящие и нисходящие потоки, вихрь, торнадо.

------------------------------------------------------------------

## Встроенные сценарии

Суперячейка (несколько вариантов, в том числе на растянутой сетке), линия шквалов, одиночная ячейка, мультиячейка, импульсная гроза, MCS, деречо, HSLC, линия пузырей, холодный бассейн, ураган, торнадо-сетка и другие. Всего 17.

------------------------------------------------------------------

## Точность

1. Шаг совпадает побитово с CM1, собранной с корректно округлённой libm. Со штатной сборкой CM1 отличия на уровне округления float.
2. Проверено на встроенных сценариях, суперячейка совпала на 600 шагах подряд (час модели). Для части сценариев эталонного прогона CM1 нет, они собраны из сверенных частей.
3. Опции CM1, которые ещё не перенесены, редактор помечает как «нет в порте».
4. Сверка шага встроена в сайт, кнопка «Сверить».

------------------------------------------------------------------

## Как запустить

```
python3 tools/serve.py
```

Потом открыть http://localhost:8990/web/ в браузере с WebGPU.

------------------------------------------------------------------

## Ограничения

1. Проверено в Safari. В других браузерах с WebGPU должно работать, но пока не проверялось.
2. Ураган и торнадо-сетка тяжёлые: нужно 8+ ГБ свободной памяти, шаг идёт секунды.
3. Сухой 2D-пузырь (isnd=1) пока не перенесён.

------------------------------------------------------------------

## Лицензия

AGPL-3.0, полный текст в `LICENSE`.

1. Код можно брать, менять и использовать, но всё, что из него сделано, тоже обязано быть открытым под AGPL-3.0. Это касается и сайтов: если у тебя на сервере крутится изменённая версия, её посетители вправе получить исходники.
2. Надпись «ThunderEngine» и ссылку на этот репозиторий убирать из интерфейса нельзя (дополнительное условие по пункту 7(b), см. `NOTICE`).
3. Чужой код внутри (CM1, RRTMG, схемы из WRF) идёт под своими лицензиями, они перечислены в `NOTICE`.

------------------------------------------------------------------

## Благодарности

CM1 написал George Bryan (NCAR). Здесь его модель, перенесённая в браузер.

==================================================================

# ThunderEngine (English)

ThunderEngine is a port of CM1 r20.2 (Cloud Model 1) to the browser: the CM1 dynamics and its main schemes, computed on the GPU through WebGPU.

Website: https://defds7721-cyber.github.io/thunderengine-web/

------------------------------------------------------------------

## What it can do

1. Run simulations from built-in soundings or your own.
2. Work on any device with WebGPU. The whole model runs on the GPU right in the browser, nothing to install.
3. Make your own presets: every CM1 configuration field in the editor, with a description of each field and a check that the scenario builds.
4. Build a sounding by hand: Skew-T and hodograph, drag points with a mouse or finger. CAPE, CIN, LCL, LFC, EL, bulk shear and SRH update live.
5. Load what you already have: a CM1 `input_sounding` or `namelist.input` file.
6. Share a preset with one link, sounding included.
7. Show the storm: slices at any height, vertical cross-section, wind arrows, 3D, view from the ground.
8. Look back at earlier moments of the run on a timeline without stopping the model.
9. Take large grids, up to 4 GB of memory (hurricane, 100 m tornado grid). They fit, but run slowly.
10. Russian and English interface.

------------------------------------------------------------------

## Layers

1. Reflectivity (composite or at a height)
2. Vertical velocity
3. Vorticity ζ
4. Clouds
5. θ′
6. Wind
7. Radial velocity from a radar, place the radar yourself

In 3D: isosurfaces of reflectivity, cloud, rain, hail, updrafts and downdrafts, vorticity, tornado.

------------------------------------------------------------------

## Built-in scenarios

Supercell (several variants, including a stretched grid), squall line, single cell, multicell, pulse storm, MCS, derecho, HSLC, bubble line, cold pool, hurricane, tornado grid and more. 17 in total.

------------------------------------------------------------------

## Accuracy

1. A step matches CM1 built with a correctly rounded libm bit for bit. Against a stock CM1 build the differences are at float rounding level.
2. Checked on the built-in scenarios; the supercell matched for 600 steps in a row (one hour of model time). For some scenarios there is no reference CM1 run, they are assembled from verified parts.
3. CM1 options that are not ported yet are marked as "not in the port" in the editor.
4. The step check is built into the site, the "Verify" button.

------------------------------------------------------------------

## How to run

```
python3 tools/serve.py
```

Then open http://localhost:8990/web/ in a browser with WebGPU.

------------------------------------------------------------------

## Limitations

1. Tested in Safari. Other browsers with WebGPU should work but have not been tested yet.
2. The hurricane and the tornado grid are heavy: they need 8+ GB of free memory, and a step takes seconds.
3. The dry 2D bubble (isnd=1) is not ported yet.

------------------------------------------------------------------

## License

AGPL-3.0, full text in `LICENSE`.

1. You may take, modify and use the code, but anything built from it must also be open source under AGPL-3.0. This includes websites: if a modified version runs on your server, its visitors are entitled to the source.
2. The "ThunderEngine" name and the link to this repository must stay in the user interface (additional term under section 7(b), see `NOTICE`).
3. Third-party code inside (CM1, RRTMG, WRF schemes) keeps its own licenses, listed in `NOTICE`.

------------------------------------------------------------------

## Credits

CM1 was written by George Bryan (NCAR). This is his model, brought to the browser.
