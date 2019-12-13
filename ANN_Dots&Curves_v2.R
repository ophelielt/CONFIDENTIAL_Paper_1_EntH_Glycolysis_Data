####ANN building and running with NeuralNet package####
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
    NeuralNet <- neuralnet(form, train_data, hidden = i, likelihood = TRUE, act.fct = "logistic")
    nn_result <- compute(NeuralNet, test_data)
    predValue  <- c(predValue, nn_result$net.result)}
  #---Save the AIC values---
  aic <- c(aic, NeuralNet$result.matrix[4])
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
  cat(i,denorm_rmse,aic,file = "denormalised_RMSE_tanh_loocv.txt", sep = "\n", append = T)
  
  denorm_mse <- mse(denormalizeddata_log$Exp_Jobs, denormalizeddata_log$ANN_Jpred_de_log)
  cat(i,denorm_mse,file = "denormalised_MSE_tanh_loocv.txt", sep = "\n", append = T)
}

#---Run the best ANN model---
#---Import the Train and Test datasets---
mytraindata <- read.csv("../Input_ANN_Table1_pH6.csv",
                        header = TRUE, sep = ";")
mytestdata <- read.csv("../Table3_dataset_NewData_COPASIPred_TEST.csv",
                       header = TRUE, sep = ";")

#---Normalize the Data---
normalisedData <- as.data.frame(apply(mytraindata, 2,  normalize))

normalizeTest <- function(trainData,testData,col1,col2) {
  col1 <- trainData[,col1]
  col2 <- testData[,col2]
  return( (col2 - min(col1))/(max(col1) - min(col1)))
}
normalisedTest <-as.data.frame(cbind(normalizeTest(mytraindata,mytestdata,1,1),
                                     normalizeTest(mytraindata,mytestdata,2,2),
                                     normalizeTest(mytraindata,mytestdata,3,3)))
colnames(normalisedTest) <- colnames(mytestdata[,1:3])

#---Set the seed and Build the ANN model using train data---
set.seed(1)
train_data <- normalisedData
form <- as.formula("Jobs~PGAM+ENO+PPDK")
##Choose the right activation function and hidden units
model <- neuralnet(form, train_data, hidden = 1, act.fct = "logistic",likelihood = TRUE)

#---Prediction and Denormalization the data---
pred <- neuralnet::compute(model, normalisedTest)
denormPred <- (pred$net.result * (max(mytraindata$Jobs) - min(mytraindata$Jobs)) + min(mytraindata$Jobs))
df <- cbind(mytestdata, denormPred)
colnames(df) <- c("PGAM","ENO", "PPDK","Jpred_Obs", "ANN_Jpred")
stat <- c(postResample(df$Jpred_Obs, df$ANN_Jpred),model$result.matrix[4])

#---Save the different results---
write.csv2(df, file = "ANN_LOO_ExpData_Neuralnet_1HU_log.csv")
write(stat, file = "Stat_LOO_ExpData_Neuralnet_1HU_log.txt" )


####ANN building and running with NNet package####
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
#---Create the function to normalize and to calculate AIC---
normalize <- function(x) {
  x <- as.numeric(x)
  return( (x - min(x))/ (max(x) - min(x)))}

akaike<-function(npar,loglik,k){-2*loglik+k*npar}

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
  #---Save the AIC values---
  SSE <- sse(normalisedData$Jobs,predValue)
  AIC <- c(AIC,akaike((4*i+(i+1)),-SSE/n,2))
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
  cat(i,denorm_rmse,AIC,file = "denormalised_RMSE_NNet_loocv_1_30.txt", sep = "\n", append = T)
  
  denorm_mse <- mse(denormalizeddata_nnet$ANN_Jpred_Nnet, denormalizeddata_nnet$Exp_Jobs)
  cat(i,denorm_mse,file = "denormalised_MSE_NNet_loocv_1_30.txt", sep = "\n", append = T)
}

#---Run the best ANN model---
#---Import the Train and Test datasets---
mytraindata <- read.csv("../Input_ANN_Table1_pH6.csv",
                        header = TRUE, sep = ";")
mytestdata <- read.csv("../Table3_dataset_NewData_COPASIPred_TEST.csv",
                       header = TRUE, sep = ";")

#---Normalize the Data---
normalisedData <- as.data.frame(apply(mytraindata, 2,  normalize))

normalizeTest <- function(trainData,testData,col1,col2) {
  col1 <- trainData[,col1]
  col2 <- testData[,col2]
  return( (col2 - min(col1))/(max(col1) - min(col1)))
}
normalisedTest <-as.data.frame(cbind(normalizeTest(mytraindata,mytestdata,1,1),
                                     normalizeTest(mytraindata,mytestdata,2,2),
                                     normalizeTest(mytraindata,mytestdata,3,3)))
colnames(normalisedTest) <- colnames(mytestdata[,1:3])

#---Prepare the dataset for the calculation of SSE---
TestJobsNorm <-as.data.frame(normalizeTest(mytraindata,mytestdata,4,4))
colnames(TestJobsNorm) <- "Jobs"

#---Set the seed and Build the ANN model using train data---
set.seed(1)
train_data <- normalisedData
form <- as.formula("Jobs~PGAM+ENO+PPDK")
##Choose the number of hidden units
model <- nnet(form, data = train_data, linout = TRUE, size = 23,  maxit = 1000)

#---Prediction and Denormalization the data---
pred <- predict(model, normalisedTest)
denormPred <- (pred * (max(mytraindata$Jobs) - min(mytraindata$Jobs)) + min(mytraindata$Jobs))
df <- cbind(mytestdata, denormPred)
colnames(df) <- c("PGAM","ENO", "PPDK","Jpred_Obs", "ANN_Jpred")
stat <- c(postResample(df$Jpred_Obs, df$ANN_Jpred))

#---Save the different results---
write.csv2(df, file = "ANN_LOO_ExpCurves_Nnet_23HU_log.csv")
write(stat, file = "Stat_LOO_ExpCurves_Nnet_23HU_log.txt" )
