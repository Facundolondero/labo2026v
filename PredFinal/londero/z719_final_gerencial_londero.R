# =====================================================================================================
#  z719 final gerencial, version de Facundo Londero
#  Prediccion final para la competencia Kaggle  labo-1-virtual-2026-manager  (future = 202109)
# =====================================================================================================
# Parte del notebook de la catedra  PredFinal/z719_final_gerencial.ipynb  (repo labo-imp/labo2026v,
# version del 13-oct-2026) y le aplica las Recomendaciones Concretas de los Experimentos Colaborativos
# mas dos ultimos experimentos propios. Cada cambio esta marcado en el codigo con  ### CAMBIO n :
#
#   1. Training Strategy (Exp. #07 Grupo A, Londero y Medina Raed): grid search con training 202103 a
#      202106 y validacion 202107; modelo final con 202103 a 202107. Quedan afuera todo 2020 y enero y
#      febrero de 2021. (+5,08 de ganancia Public sobre la linea base, 10 de 10 semillas, Wilcoxon p = 0,002)
#   2. campos_buenos sin numero_de_cliente ni foto_mes (Exp. #16 Grupo B: +3,35 M, 10 de 10, p = 0,0059;
#      el Grupo A del #16 no encontro diferencia, asi que sacarlos no tiene costo).
#   3. Modelo final armado con modifyList(): el notebook usa c(fijos, mejores), que deja num_leaves y
#      min_data_in_leaf duplicados y LightGBM se queda con los fijos, o sea que ignora el grid search
#      (reportado en el Exp. #07; el Exp. #05 lo corrigio igual).
#   4. Ultimo experimento propio A, grilla ampliada en los bordes: en las 40 corridas del Exp. #07 el
#      optimo cayo en el borde de la grilla en 28 (min_data_in_leaf 64 o num_leaves 512). Se agregaron
#      16 y 32 abajo de min_data_in_leaf y 1024 arriba de num_leaves (corrida WF7301); como el optimo
#      volvio a caer en el borde (min_data_in_leaf 16), se agregan tambien 4 y 8 (corrida WF7302).
#   5. Ultimo experimento propio B, semillerio: el modelo final se entrena con 10 semillas y se
#      promedian las probabilidades (PDF 0899 de la Clase 08; Exp. #14 Grupo A).
#
# Todo lo demas es el notebook tal cual: Catastrophe Analysis, FE intra-mes, FE historico (lags y deltas
# de orden 1 y 2), sin data drifting, sin canaritos, training_pct 1, parametros fijos de LightGBM,
# metrica AUC en el grid y cortes de 800 a 1300 envios.
#
# Uso local:   Rscript z719_final_gerencial_londero.R [test|full]
#   test = grilla de 2 combinaciones, 2 semillas y pocas iteraciones, solo para probar el circuito
#   full = la corrida real (WF7301)
# En Google Colab (kernel R) el mismo codigo detecta /content y usa las carpetas de la catedra.
# NO sube nada a Kaggle salvo que PARAM$kaggle$subir sea TRUE.
# =====================================================================================================

# =====================================================================================================
#  1. Inicializacion y parametros
# =====================================================================================================
args <- commandArgs(trailingOnly = TRUE)
modo <- if (length(args) >= 1) args[1] else "full"
stopifnot(modo %in% c("test", "full"))

rm(list = setdiff(ls(all.names = TRUE), "modo"))
gc(full = TRUE, verbose = FALSE)

require("data.table")
if (!require("R.utils")) install.packages("R.utils")
require("R.utils")
if (!require("lightgbm")) install.packages("lightgbm")
require("lightgbm")
if (!require("yaml")) install.packages("yaml")
require("yaml")

PARAM <- list()
PARAM$semilla_primigenia <- 999983           # primo propio
PARAM$experimento <- if (modo == "full") 7302 else 7300
PARAM$dataset <- "gerencial_competencia_2026.csv.gz"
PARAM$modo <- modo
PARAM$autor <- "Facundo Londero"
PARAM$base <- "labo-imp/labo2026v PredFinal/z719_final_gerencial.ipynb (13-oct-2026)"

### CAMBIO 5: semillas del semillerio, todas primos propios (en modo test solo las dos primeras)
PARAM$semillerio <- c(999983, 150001, 222247, 199999, 777781,
                      553897, 761897, 815197, 906187, 919531)
if (modo == "test") PARAM$semillerio <- PARAM$semillerio[1:2]

# carpetas: en Colab las de la catedra, en esta PC las del proyecto
en_colab <- dir.exists("/content")
if (en_colab) {
  carpeta_datasets <- "/content/datasets/"
  carpeta_exp <- "/content/buckets/b1/exp/"
} else {
  carpeta_datasets <- "C:/Users/facun/Downloads/labo1/exp07/datasets/"
  carpeta_exp <- "C:/Users/facun/Downloads/labo1/predfinal/exp/"
}
dir.create(carpeta_exp, recursive = TRUE, showWarnings = FALSE)
experimento_folder <- paste0("WF", PARAM$experimento)
dir.create(file.path(carpeta_exp, experimento_folder), showWarnings = FALSE)
setwd(file.path(carpeta_exp, experimento_folder))

# el dataset: si no esta, se baja de donde lo publica la catedra
archivo_dataset <- file.path(carpeta_datasets, PARAM$dataset)
if (!file.exists(archivo_dataset)) {
  dir.create(carpeta_datasets, recursive = TRUE, showWarnings = FALSE)
  download.file(paste0("https://storage.googleapis.com/open-courses/austral2026-5da5/labo1/", PARAM$dataset),
                archivo_dataset, mode = "wb")
}

t_inicio <- Sys.time()
message(format(t_inicio, "%a %b %d %X %Y"), "  arranca ", experimento_folder, " en modo ", modo,
        "  carpeta ", getwd())

# =====================================================================================================
#  2. Preprocesamiento del dataset (identico al notebook)
# =====================================================================================================
dataset <- fread(archivo_dataset)

# --- 6.3.1.2 CA Catastrophe Analysis: las variables rotas de 202006 pasan a NA ---
dataset[ foto_mes==202006, internet:=NA]
dataset[ foto_mes==202006, mrentabilidad:=NA]
dataset[ foto_mes==202006, mrentabilidad_annual:=NA]
dataset[ foto_mes==202006, mcomisiones:=NA]
dataset[ foto_mes==202006, mactivos_margen:=NA]
dataset[ foto_mes==202006, mpasivos_margen:=NA]
dataset[ foto_mes==202006, mcuentas_saldo:=NA]
dataset[ foto_mes==202006, ctarjeta_visa_transacciones:=NA]
dataset[ foto_mes==202006, mtarjeta_visa_consumo:=NA]
dataset[ foto_mes==202006, mtarjeta_master_consumo:=NA]
dataset[ foto_mes==202006, ccallcenter_transacciones:=NA]
dataset[ foto_mes==202006, chomebanking_transacciones:=NA]

# --- 6.3.1.3 DR Data Drifting: sin codigo, como en el notebook (Exp. #02: corregirlo no mejoro la ganancia) ---

# --- 6.3.1.3 FE intra-mes manual ---
atributos_presentes <- function( patributos )
{
  atributos <- unique( patributos )
  comun <- intersect( atributos, colnames(dataset) )
  return(  length( atributos ) == length( comun ) )
}

if( atributos_presentes( c("foto_mes") ))
  dataset[, kmes := foto_mes %% 100]

if( atributos_presentes( c("mpayroll", "cliente_edad") ))
  dataset[, mpayroll_sobre_edad := mpayroll / cliente_edad]

# --- 6.3.1.4 FE a partir de Random Forest: no se implementa (como en el notebook) ---

# --- 6.3.1.5 FE historico: lags y deltas de orden 1 y 2 (Exp. #05: los lags largos empeoran) ---
cols_lagueables <- copy( setdiff(
    colnames(dataset),
    c("numero_de_cliente", "foto_mes", "clase_ternaria")
) )

dataset[,
    paste0(cols_lagueables, "_lag1") := shift(.SD, 1, NA, "lag"),
    by = numero_de_cliente,
    .SDcols = cols_lagueables
]

dataset[,
    paste0(cols_lagueables, "_lag2") := shift(.SD, 2, NA, "lag"),
    by = numero_de_cliente,
    .SDcols = cols_lagueables
]

for (vcol in cols_lagueables)
{
    dataset[, paste0(vcol, "_delta1") := get(vcol) - get(paste0(vcol, "_lag1"))]
    dataset[, paste0(vcol, "_delta2") := get(vcol) - get(paste0(vcol, "_lag2"))]
}

# --- 6.3.1.6 Reduccion de dimensionalidad con canaritos: no se implementa (Exp. #06: no supera al baseline) ---

PARAM$out$ncol_dataset <- ncol(dataset)
message(format(Sys.time(), "%a %b %d %X %Y"), "  preprocesamiento listo: ", nrow(dataset), " filas x ",
        ncol(dataset), " columnas")

# =====================================================================================================
#  3. Training Strategy
# =====================================================================================================
### CAMBIO 1: se entrena solo desde marzo de 2021
PARAM$trainingstrategy$validate <- c(202107)
PARAM$trainingstrategy$training <- c( 202106, 202105, 202104, 202103 )
PARAM$trainingstrategy$training_pct <- 1.0
PARAM$trainingstrategy$positivos <- c( "BAJA+1", "BAJA+2")

dataset[, clase01 := ifelse( clase_ternaria %in% PARAM$trainingstrategy$positivos, 1, 0 )]

### CAMBIO 2: los campos en los que se entrena, sin el identificador ni el mes
PARAM$campos_excluidos <- c("numero_de_cliente", "foto_mes")
campos_buenos <- copy( setdiff(
    colnames(dataset), c("clase_ternaria", "clase01", "azar", PARAM$campos_excluidos))
)
PARAM$out$n_campos_buenos <- length(campos_buenos)

set.seed(PARAM$semilla_primigenia, kind = "L'Ecuyer-CMRG")
dataset[, azar:=runif(nrow(dataset))]

dataset[, fold_train :=  foto_mes %in%  PARAM$trainingstrategy$training &
    (clase_ternaria %in% c("BAJA+1", "BAJA+2") |
     azar < PARAM$trainingstrategy$training_pct ) ]

dtrain <- lgb.Dataset(
  data= data.matrix(dataset[fold_train == TRUE, campos_buenos, with = FALSE]),
  label= dataset[fold_train == TRUE, clase01],
  free_raw_data= TRUE
)

dvalidate <- lgb.Dataset(
  data= data.matrix(dataset[foto_mes %in% PARAM$trainingstrategy$validate, campos_buenos, with = FALSE]),
  label= dataset[foto_mes %in% PARAM$trainingstrategy$validate, clase01],
  free_raw_data= TRUE
)

PARAM$out$n_train <- dataset[fold_train == TRUE, .N]
PARAM$out$positivos_train <- dataset[fold_train == TRUE, sum(clase01)]
PARAM$out$baja2_train <- dataset[fold_train == TRUE, sum(clase_ternaria == "BAJA+2")]
message(format(Sys.time(), "%a %b %d %X %Y"), "  training: ", PARAM$out$n_train, " filas, ",
        PARAM$out$positivos_train, " positivos, ", PARAM$out$baja2_train, " BAJA+2; ",
        length(campos_buenos), " campos")

# =====================================================================================================
#  4. Hyperparameter Tuning: grid search por AUC en 202107 (como el notebook, con la grilla ampliada)
# =====================================================================================================
PARAM$lgbm$param_fijos <- list(
  objective= "binary",
  metric= "auc",
  first_metric_only= TRUE,
  boost_from_average= TRUE,
  feature_pre_filter= FALSE,
  verbosity= -100,
  force_row_wise= TRUE,
  seed= PARAM$semilla_primigenia,
  max_bin= 31,
  learning_rate= 0.03,
  feature_fraction= 0.5,
  num_iterations= 2048,
  early_stopping_rounds= 200,
  num_leaves= 64,
  min_data_in_leaf= 128
)
if (modo == "test") PARAM$lgbm$param_fijos$num_iterations <- 200

Estimar_AUC_lightgbm <- function(x) {
  param_completo <- modifyList(PARAM$lgbm$param_fijos, x)
  modelo_train <- lgb.train(
    data= dtrain,
    valids= list(valid = dvalidate),
    eval= "auc",
    param= param_completo,
    verbose= -100
  )
  AUC <- modelo_train$record_evals$valid$auc$eval[[modelo_train$best_iter]]
  message(format(Sys.time(), "%a %b %d %X %Y  "),
    toString(x),
    " niter ", modelo_train$best_iter,
    " AUC ", AUC
  )
  niter <- modelo_train$best_iter
  rm(modelo_train)
  gc(full= TRUE, verbose= FALSE)
  return( list(AUC, niter))
}

### CAMBIO 4: la grilla del notebook (64..512 x 64..2048) ampliada hacia los bordes donde cayo el optimo
if (modo == "full") {
  tb_nueva <- CJ(
    num_leaves= c(64, 128, 256, 512, 1024),
    min_data_in_leaf= c(4, 8, 16, 32, 64, 256, 512, 1024, 2048)
  )
} else {
  tb_nueva <- CJ( num_leaves= c(64, 512), min_data_in_leaf= c(64) )
}
PARAM$lgbm$grilla <- list(num_leaves = sort(unique(tb_nueva$num_leaves)),
                          min_data_in_leaf = sort(unique(tb_nueva$min_data_in_leaf)))

tb_nueva[, c("AUC", "num_iterations"):= Estimar_AUC_lightgbm( .SD ),
  by=1:nrow(tb_nueva) ]

fwrite( tb_nueva, file= "tb_grid_search_01.txt", sep="\t" )

setorder( tb_nueva, -AUC)
PARAM$out$lgbm$AUC <- tb_nueva[1, AUC]
PARAM$out$lgbm$mejores_hiperparametros <- as.list( tb_nueva[1] )
PARAM$out$lgbm$mejores_hiperparametros$AUC <- NULL
PARAM$out$lgbm$optimo_en_borde <- list(
  num_leaves = tb_nueva[1, num_leaves] %in% range(PARAM$lgbm$grilla$num_leaves),
  min_data_in_leaf = tb_nueva[1, min_data_in_leaf] %in% range(PARAM$lgbm$grilla$min_data_in_leaf)
)
message(format(Sys.time(), "%a %b %d %X %Y"), "  mejores: ", toString(PARAM$out$lgbm$mejores_hiperparametros),
        "  AUC ", PARAM$out$lgbm$AUC, "  borde: ", toString(unlist(PARAM$out$lgbm$optimo_en_borde)))

# =====================================================================================================
#  5. Produccion: final training con semillerio y scoring de 202109
# =====================================================================================================
### CAMBIO 1: el modelo final tambien arranca en marzo de 2021
PARAM$trainingstrategy$final_train <- c( 202107, 202106, 202105, 202104, 202103 )

dataset[, fold_final_train := foto_mes %in% PARAM$trainingstrategy$final_train ]

dfinal_train <- lgb.Dataset(
  data= data.matrix(dataset[fold_final_train == TRUE, campos_buenos, with= FALSE]),
  label= dataset[fold_final_train == TRUE, clase01],
  free_raw_data= TRUE
)
PARAM$out$n_final_train <- dataset[fold_final_train == TRUE, .N]

fijos <- copy(PARAM$lgbm$param_fijos)
fijos$num_iterations <- NULL
fijos$early_stopping_rounds <- NULL

### CAMBIO 3: modifyList en vez de c(): los mejores hiperparametros del grid PISAN a los fijos
param_final <- modifyList(fijos, PARAM$out$lgbm$mejores_hiperparametros)
PARAM$out$param_final <- param_final

PARAM$trainingstrategy$future <- c(202109)
dfuture <- dataset[ foto_mes %in% PARAM$trainingstrategy$future ]
mfuture <- data.matrix(dfuture[, campos_buenos, with= FALSE])

tb_prediccion <- dfuture[, list(numero_de_cliente)]

### CAMBIO 5: semillerio, un modelo final por semilla y promedio de las probabilidades
for (semilla in PARAM$semillerio) {
  param_semilla <- param_final
  param_semilla$seed <- semilla

  modelo_semilla <- lgb.train(
    data= dfinal_train,
    param= param_semilla,
    verbose= -100
  )

  lgb.save(modelo_semilla, paste0("modelo_s", semilla, ".txt"))

  if (semilla == PARAM$semillerio[1]) {
    tb_importancia <- as.data.table(lgb.importance(modelo_semilla))
    fwrite( tb_importancia, file= "impo.txt", sep= "\t" )
  }

  tb_prediccion[, paste0("prob_s", semilla) := predict(modelo_semilla, mfuture)]
  message(format(Sys.time(), "%a %b %d %X %Y"), "  semilla ", semilla, " lista")

  rm(modelo_semilla)
  gc(full= TRUE, verbose= FALSE)
}

tb_prediccion[, prob := rowMeans(.SD), .SDcols = patterns("^prob_s")]

fwrite(tb_prediccion, file= "prediccion.txt", sep= "\t")

# =====================================================================================================
#  6. Archivos para Kaggle
# =====================================================================================================
PARAM$kaggle$competencia <- "labo-1-virtual-2026-manager"
PARAM$kaggle$cortes <- seq(800, 1300, by = 50)
PARAM$kaggle$cortes_extra <- c(seq(600, 750, by = 50), seq(1350, 1500, by = 50))
PARAM$kaggle$subir <- FALSE          # la subida se hace aparte, envio por envio

setorder(tb_prediccion, -prob)

dir.create("kaggle", showWarnings = FALSE)

for (envios in sort(c(PARAM$kaggle$cortes, PARAM$kaggle$cortes_extra))) {

  tb_prediccion[, Predicted := 0L]
  tb_prediccion[1:envios, Predicted := 1L]

  archivo_kaggle <- paste0("./kaggle/KA", PARAM$experimento, "_", envios, ".csv")

  fwrite(tb_prediccion[, list(numero_de_cliente, Predicted)],
    file= archivo_kaggle,
    sep= ","
  )

  if (PARAM$kaggle$subir && envios %in% PARAM$kaggle$cortes) {
    comando <- "kaggle competitions submit"
    competencia <- paste("-c", PARAM$kaggle$competencia)
    arch <- paste( "-f", archivo_kaggle)
    mensaje <- paste0("-m 'envios=", envios, "  semillerio=", length(PARAM$semillerio),
                      "  exp=", PARAM$experimento, "'")
    linea <- paste( comando, competencia, arch, mensaje)
    Sys.sleep(30)
    salida <- system(linea, intern=TRUE)
    cat(salida, "\n")
  }
}

# =====================================================================================================
#  7. Parametros y entorno, para poder replicar exactamente
# =====================================================================================================
PARAM$out$entorno <- list(
  R = R.version.string,
  lightgbm = as.character(packageVersion("lightgbm")),
  data.table = as.character(packageVersion("data.table")),
  sistema = Sys.info()[["sysname"]],
  nucleos = parallel::detectCores()
)
PARAM$out$minutos <- round(as.numeric(difftime(Sys.time(), t_inicio, units = "mins")), 1)

write_yaml( PARAM, file="PARAM.yml")

message(format(Sys.time(), "%a %b %d %X %Y"), "  FIN ", experimento_folder, " en ", PARAM$out$minutos, " minutos")
