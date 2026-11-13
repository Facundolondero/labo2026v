# Predicción final gerencial · Facundo Londero

Solución final para la competencia Kaggle `labo-1-virtual-2026-manager` (future = 202109), modalidad Gerencial.
Laboratorio de Implementación I, Maestría en Explotación de Datos y Gestión del Conocimiento, Universidad Austral, noviembre de 2026.

## Envío final

| | |
|---|---|
| Archivo | `kaggle/KA7302_1250.csv` (1.250 envíos) |
| md5 | `dd143a23c92da4d2e4d1fabe35b3c875` con fin de línea LF, que es como queda el archivo en este repositorio y como lo escribe `fwrite` en Colab. El archivo subido a Kaggle se generó en Windows, con fin de línea CRLF: md5 `37a59a14f87802d96de88d4b7b3710aa`, mismo contenido |
| Envío en Kaggle | ref 58216596, 10-nov-2026, descripción `z719 londero exp7302 envios=1250 semillerio=10 FINAL`, Public 23,402 |
| Probabilidades | `prediccion.txt` (promedio del semillerío y una columna por semilla), md5 `9abfd73fca24b863045bc531179ddc83` con LF y `bc5ce38e9198589f9764e5bd4a4b31b5` con CRLF |

Los cortes `KA7301_*` que también figuran en la cuenta (800 a 1.500) salieron de una corrida previa con la grilla de 35 combinaciones (WF7301). Como la grilla ampliada de 45 (WF7302, la de este notebook) eligió los mismos hiperparámetros y las semillas son las mismas, los archivos de las dos corridas son idénticos byte a byte; `KA7301_1250.csv` tiene el mismo md5 que `KA7302_1250.csv`.

## Qué cambia respecto del z719 de la cátedra

Se parte de `PredFinal/z719_final_gerencial.ipynb` (repo `labo-imp/labo2026v`, versión del 13-oct-2026). Cada cambio está marcado en el código con `### CAMBIO n`.

1. **Training Strategy** (Experimento Colaborativo #07, Grupo A, Londero y Medina Raed): grid search con training 202103 a 202106 y validación 202107; modelo final con 202103 a 202107. Quedan afuera todo 2020 y enero y febrero de 2021. En el experimento, entrenar desde 202103 dio +5,08 de ganancia Public sobre la línea base, 10 de 10 semillas, Wilcoxon p = 0,002.
2. **campos_buenos sin `numero_de_cliente` ni `foto_mes`** (Experimento #16, Grupo B: +3,35 M, 10 de 10 semillas, p = 0,0059; el Grupo A del #16 no encontró diferencia, así que sacarlos no tiene costo).
3. **Modelo final con `modifyList()`**: el notebook arma `param_final <- c(fijos, mejores)`, que deja `num_leaves` y `min_data_in_leaf` duplicados y LightGBM se queda con los fijos, o sea que ignora el grid search. Reportado en el Experimento #07 y corregido también por el #05.
4. **Grilla ampliada en los bordes** (último experimento propio A): en las 40 corridas del Experimento #07 el óptimo cayó en el borde de la grilla en 28. La grilla pasa a `num_leaves` {64, 128, 256, 512, 1024} × `min_data_in_leaf` {4, 8, 16, 32, 64, 256, 512, 1024, 2048}, 45 combinaciones. El óptimo quedó adentro: 128 hojas y 16 datos por hoja.
5. **Semillerío** (último experimento propio B): el modelo final se entrena con 10 semillas, todas primos propios, y se promedian las probabilidades. PDF 0899 de la Clase 08 y Experimento #14, Grupo A.

Todo lo demás es el notebook tal cual: Catastrophe Analysis con NA en 202006, FE intra-mes (`kmes`, `mpayroll_sobre_edad`), FE histórico con lags y deltas de orden 1 y 2, sin data drifting (Experimento #02: corregirlo no mejoró la ganancia), sin canaritos (Experimento #06: no supera al baseline), `training_pct` 1 (Experimento #09: el recorte no cambia la ganancia), parámetros fijos de LightGBM y métrica AUC en el grid.

## Cómo replicar

**En Google Colab**: subir `z719_final_gerencial_londero.ipynb`, correr las dos primeras celdas de código con el runtime en Python 3 (montan el Drive, copian `kaggle.json` y bajan el dataset, igual que el z719), cambiar el runtime a R y correr el resto. Las salidas quedan en `/content/buckets/b1/exp/WF7302/`.

**En una PC con R** (R 4.6.1, `data.table` 1.18.4, `lightgbm` 4.7.0, `yaml`, `R.utils`):

```
Rscript z719_final_gerencial_londero.R full
```

El script baja el dataset `gerencial_competencia_2026.csv.gz` si no lo encuentra y escribe en `exp/WF7302/`: `tb_grid_search_01.txt`, `modelo_s<semilla>.txt` (los 10 modelos), `impo.txt`, `prediccion.txt`, `kaggle/KA7302_<envios>.csv` para los cortes 600 a 1.500 de a 50, y `PARAM.yml` con todos los parámetros, los mejores hiperparámetros, la grilla, el chequeo de borde y el entorno. `Rscript z719_final_gerencial_londero.R test` prueba el circuito en un minuto con una grilla de dos combinaciones.

No sube nada a Kaggle salvo que se ponga `PARAM$kaggle$subir <- TRUE`. En esta PC de 16 núcleos la corrida completa tardó 105 minutos (la grilla de 45 combinaciones, unas 2 horas y media más el semillerío, que son 5 minutos).

El código R del notebook es exactamente el del script `.R`, partido en secciones. Semilla primigenia 999983 para el grid y el muestreo; semillas del semillerío 999983, 150001, 222247, 199999, 777781, 553897, 761897, 815197, 906187 y 919531. Con `force_row_wise = TRUE` y las semillas fijas, dos corridas en la misma máquina dieron resultados idénticos (WF7301 y WF7302 coinciden en las 35 combinaciones comunes y en los 19 archivos de cortes).

## Resultados del grid search (validación 202107, AUC)

| num_leaves | min_data_in_leaf | AUC | iteraciones |
|---|---|---|---|
| **128** | **16** | **0,94857** | **110** |
| 1024 | 8 | 0,94849 | 511 |
| 512 | 4 | 0,94813 | 631 |
| 512 | 64 | 0,94781 | 650 |
| 256 | 32 | 0,94772 | 321 |

Training del grid: 52.606 filas y 671 positivos (333 BAJA+2); entrenamiento final: 65.808 filas; 155 campos. La tabla completa de las 45 combinaciones está en `tb_grid_search_01.txt`.

## Curva de ganancia Public (cuenta facundolonderoj, 10-nov-2026)

| Envíos | 800 | 850 | 900 | 950 | 1000 | 1050 | 1100 | 1150 | 1200 | 1250 | 1300 | 1350 | 1400 | 1450 | 1500 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Public | 20,99 | 20,07 | 22,15 | 20,90 | 19,49 | 21,49 | 20,15 | 18,91 | 24,65 | 23,40 | 21,74 | 20,15 | 21,74 | 20,32 | 19,07 |

La curva es ruidosa, con saltos de hasta 2 puntos entre cortes vecinos. El envío final no se eligió por el máximo (1.200) sino por el centro de la zona alta, 1.200 a 1.300, que es donde la curva suavizada con media móvil de tres cortes tiene su máximo: 1.250.

## Archivos

| Archivo | Contenido |
|---|---|
| `z719_final_gerencial_londero.ipynb` | Notebook para Colab, mismo código que el script |
| `z719_final_gerencial_londero.R` | Script completo, corre en Colab o en una PC |
| `PARAM.yml` | Parámetros de la corrida WF7302, hiperparámetros elegidos, grilla, borde, entorno |
| `tb_grid_search_01.txt` | Las 45 combinaciones del grid con AUC e iteraciones |
| `impo.txt` | Importancia de variables del modelo de la primera semilla |
| `prediccion.txt` | Probabilidad promedio y por semilla de los 13.242 clientes de 202109 |
| `kaggle/` | Los 19 archivos de cortes, 600 a 1.500 envíos; el final es `KA7302_1250.csv` |
