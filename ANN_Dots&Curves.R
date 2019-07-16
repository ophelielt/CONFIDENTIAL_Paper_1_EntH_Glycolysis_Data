####ANN building with NeuralNet package####
#---Load and install the necessary package---
library(neuralnet)
library(Metrics)
library(caret)

#---Set the seed and create folder to save the results---
set.seed(1)
dir.create("./Denormalised_LOOcv")
dir.create("./Normalised_LOOcv")
#---Create the function to normalize---
normalize <- function(x) {
  x <- as.numeric(x)
  return( (x - min(x))/ (max(x) - min(x)))
  }

#---Import the input data with dots (S1 Table) or curves (S2 Table)---
mydata <- read.csv("../Input_ANN_Table2_pH6.csv", sep=';', header = T)

#---Normalize the input data---
normalisedData <- as.data.frame(apply(mydata, 2,  normalize))

#---Build the ANN models with the learning data---
n <- nrow(mydata)

## Number of fold (if k = n, LOO)
k <- n
folds <- caret::createFolds(1:n, k)
##Choose the number of hidden units
for (i in 1:30) {
  set.seed(1)
  predValue <- NULL
  nn_result <- NULL
  for (fold in folds){
    train_data <- normalisedData[-fold, ]
    test_data  <- normalisedData[fold, c("PGAM","ENO","PPDK")]
    form <- as.formula("Jobs~PGAM+ENO+PPDK")
    ##Choose the activation function "logistic" or "tanh, stepmax = 1e+07" in the following line
    NeuralNet <- neuralnet(form, train_data, hidden = i, act.fct = "logistic")
    nn_result <- compute(NeuralNet, test_data)
    predValue  <- c(predValue, nn_result$net.result)}
  #---Create a dataframe containing the resulting predicted flux values---
  df = data.frame(normalisedData[unlist(folds),], predValue)
  colnames(df) <- c ('PGAM', 'ENO', 'PPDK', 'Jobs', 'ANN_pred_log')
  denormalizeANN_pred_log <- df$ANN_pred_log * (max(mydata$Jobs) - min(mydata$Jobs)) + min(mydata$Jobs)
  denormalizeddata_log <- cbind(mydata[unlist(folds), ], denormalizeANN_pred_log)
  colnames(denormalizeddata_log) <- c("PGAM","ENO","PPDK","Exp_Jobs","ANN_Jpred_de_log")
  
  #---Write the different outputs---
  write.csv(df, paste0("./Normalised_LOOcv/tanh_normalised",i,".csv"),row.names = F)
  write.csv(denormalizeddata_log,  paste0("./Denormalised_LOOcv/tanh_denormalised_loocv",i,".csv"),
            row.names = F)
  
  rmse_nor<- capture.output(postResample(predValue, normalisedData$Jobs[unlist(folds)]))
  cat(i,rmse_nor,file = "normalised_RMSE_tanh_loocv.csv", sep = "\n", append = T)
  
  mse_nor <- mse(predValue, normalisedData$Jobs[unlist(folds)])
  cat(i,mse_nor,file = "normalised_MSE_tanh_loocv.csv", sep = "\n", append = T)
  
  denorm_rmse <- postResample(denormalizeddata_log$Exp_Jobs, denormalizeddata_log$ANN_Jpred_de_log)
  cat(i,denorm_rmse,file = "denormalised_RMSE_tanh_loocv.txt", sep = "\n", append = T)
  
  denorm_mse <- mse(denormalizeddata_log$Exp_Jobs, denormalizeddata_log$ANN_Jpred_de_log)
  cat(i,denorm_mse,file = "denormalised_MSE_tanh_loocv.txt", sep = "\n", append = T)
}

####ANN building with NNet package####
#---Load and install the necessary package---
library(nnet)
library(Metrics)
library(caret)

#---Set the seed and create the folder---
set.seed(1)
date <- format(Sys.time(), "%m_%d_%Y_%H_%M")
denormFold <- paste0("./Denormalised_LOOcv_NNet","_", date)
normFold <- paste0("./Normalised_LOOcv_NNet","_", date)
dir.create(denormFold)
dir.create(normFold)
#---Create the function to normalize---
normalize <- function(x) {
  x <- as.numeric(x)
  return( (x - min(x))/ (max(x) - min(x)))}

#---Import the input data with dots (S1 Table) or curves (S2 Table)---
mydata <- read.csv("../Input_ANN_Table2_pH6.csv", header = TRUE, sep = ";")

#---Normalize the input data---
normalisedData <- as.data.frame(apply(mydata, 2,  normalize))

#---Build the ANN models with the learning data---
n <- nrow(mydata)


# Number of fold (if k = n, LOO)
k <- n
folds <- caret::createFolds(1:n, k)
##Choose the number of hidden units
for (i in 1:30){
  set.seed(1)
  predValue <- NULL
  nn_result <- NULL
  for (fold in folds){
    # print(fold)
    train_data <- normalisedData[-fold, ]
    test_data  <- normalisedData[fold, c("PGAM","ENO","PPDK")]
    form <- as.formula("Jobs~PGAM+ENO+PPDK")
    Nnet <- nnet(form, data = train_data, linout = TRUE, size = i,  maxit = 1000)
    nn_result <- predict(Nnet, test_data[, c("PGAM","ENO","PPDK")])
    predValue  <- c(predValue, nn_result)}
  #---Create a dataframe containing the resulting predicted flux values---
  df = data.frame(normalisedData[unlist(folds),], predValue)
  colnames(df) <- c ('PGAM', 'ENO', 'PPDK', 'Jobs', 'ANN_Jpred_Nnet')
  denormalizeANN_pred_nnet <- df$ANN_Jpred_Nnet * (max(mydata$Jobs) - min(mydata$Jobs)) + min(mydata$Jobs)
  denormalizeddata_nnet <- cbind(mydata[unlist(folds), ], denormalizeANN_pred_nnet)
  colnames(denormalizeddata_nnet) <- c("PGAM","ENO","PPDK","Exp_Jobs","ANN_Jpred_Nnet")
  
  #---Write the different outputs---
  write.csv(df, paste0(normFold,"/NNet_normalised",i,".csv"),row.names = F)
  write.csv(denormalizeddata_nnet, paste0(denormFold,"/NNet_denormalised_loocv",i,".csv"),
            row.names = F)
  
  rmse_nor<- capture.output(postResample(predValue, normalisedData$Jobs[unlist(folds)]))
  cat(i,rmse_nor,file = "normalised_RMSE_NNet_loocv_1_30.csv", sep = "\n", append = T)
  
  mse_nor <- mse(predValue, normalisedData$Jobs[unlist(folds)])
  cat(i,mse_nor,file = "normalised_MSE_NNet_loocv_1_30.csv", sep = "\n", append = T)
  
  denorm_rmse <- postResample(denormalizeddata_nnet$ANN_Jpred_Nnet, denormalizeddata_nnet$Exp_Jobs)
  cat(i,denorm_rmse,file = "denormalised_RMSE_NNet_loocv_1_30.txt", sep = "\n", append = T)
  
  denorm_mse <- mse(denormalizeddata_nnet$ANN_Jpred_Nnet, denormalizeddata_nnet$Exp_Jobs)
  cat(i,denorm_mse,file = "denormalised_MSE_NNet_loocv_1_30.txt", sep = "\n", append = T)
}
