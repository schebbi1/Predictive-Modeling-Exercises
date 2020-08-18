library(tm) #text miner
library(tidyverse)
library(slam) #good for matrices
library(proxy) #good for distance func
library(readr) # For reading each text file.
library(stringr) # For extracting the author names.
library(caret) #helps with easy predictive modeling 
library(nnet) #for computing multinomial logistic regression


### READING IN THE DATA ###

#reading in the training data
dir_train = 'C:/Users/india/Documents/GitHub/STA380/data/ReutersC50/C50train/'
files_train = list.files(dir_train, recursive=T) #vector containing all data in C50 Train folder

#initializing variables to grab train data 
train_i = 1 #index to grab all files for each author
file_train = NULL #empty vector to hold all text 
vector_train = NULL #empty vector to hold all authors names

#getting author and file vectors for the training data
for(x in 1:length(files_train)){ #loop through each entry in files_train vector
  author_train = substr(files_train[train_i], start=1, stop=str_locate(files_train[train_i], "/")-1) 
  #author_train grabs the author of each file
  file_t = read_file(paste0(dir_train, files_train[train_i]))
  #file_t grabs and combines all text from folder in C50Train directory with author's name
  file_train = c(file_train,file_t) #vector containing all text from each author
  vector_train = c(vector_train,author_train) #vector containing names of all authors
  train_i = train_i + 1 #inc. index to grab next file 
}
#vector_train contains 50 entries of each author's name 
#file_train contains 50 text files for each of the 50 authors

#reading in the test data
dir_test = 'C:/Users/india/Documents/GitHub/STA380/data/ReutersC50/C50test/'
files_test = list.files(dir_test, recursive=T) #vector containing all data in C50Test folder

#initializing same variables to grab test data
test_i = 1 #index to grab all files for each author
file_test = NULL #empty vector to hold all text 
vector_test = NULL #empty vector to hold all authors names

#getting author and file vectors for the test data
for(x in 1:length(files_test)){ #loop through each entry in files_test vector
  author_test = substr(files_test[test_i], start=1, stop=str_locate(files_test[test_i], "/")-1) 
  #author_test grabs the author of each file
  f_test = read_file(paste0(dir_test, files_test[test_i]))
  #file_test grabs and combines all text from folder in directory w authors name
  file_test = c(file_test,f_test) #vector containing all text from each author
  vector_test = c(vector_test,author_test) #vector containing names of all authors
  test_i = test_i + 1 #inc. index to grab next file 
}

#Checking to make sure we have 50 text files for 50 authors. There should be 50*50=2500 authors and text files
if(length(file_train) == 2500 & length(vector_train) == 2500){print("Train Data Read Successfully")}
if(length(file_test) == 2500 & length(vector_test) == 2500){print("Test Data Read Successfully")}

### PRE-PROCESSING: CREATING A DOC-TERM-MATRIX ###

#creating a text mining corpus for all the quotes
train_raw = Corpus(VectorSource(file_train))
#vector source reads in documents one by one
#corpus constructs a corpus consisted of all documents by one author

train_doc = train_raw %>%
  tm_map(content_transformer(tolower))  %>%             # make everything lowercase
  tm_map(content_transformer(removeNumbers)) %>%        # remove numbers
  tm_map(content_transformer(removePunctuation)) %>%    # remove punctuation
  tm_map(content_transformer(stripWhitespace))          # remove excess white-space

#using "basic English" stop words 
train_doc = tm_map(train_doc, content_transformer(removeWords), stopwords("en"))
#produces warning.. no documents are actually dropped

## create a doc-term-matrix from the corpus
DTM_train = DocumentTermMatrix(train_doc)
DTM_train # some basic summary statistics
#contains 2500 documents with 31,752 terms
#sparsity = 99% indicates we removed terms that only appear in at most 1% of the data
#maximal term length of 36 indicates that the largest number of characters within 1 term is 36


#dropping terms that only occur in one or two documents as there is nothing to learn if a term occurred once.
## Below removes those terms that have count 0 in >99% of docs.  
DTM_train = removeSparseTerms(DTM_train, 0.99)
DTM_train # now ~ 3,325 #MAYBE ADJUST THIS LATER 
DTM_train1 <- as.matrix(DTM_train)

### PRE-PROCESSING TEST SET

#creating a text mining corpus for all the quotes
test_raw = Corpus(VectorSource(file_test))
#vector source reads in documents one by one
#corpus constructs a corpus consisted of all documents by one author

test_doc = test_raw %>%
  tm_map(content_transformer(tolower))  %>%             # make everything lowercase
  tm_map(content_transformer(removeNumbers)) %>%        # remove numbers
  tm_map(content_transformer(removePunctuation)) %>%    # remove punctuation
  tm_map(content_transformer(stripWhitespace))          # remove excess white-space

#using "basic English" stop words (maybe try again with SMART?)
test_doc = tm_map(test_doc, content_transformer(removeWords), stopwords("en"))
#produces warning.. no documents are actually dropped

## create a doc-term-matrix from the corpus
DTM_test = DocumentTermMatrix(test_doc)
DTM_test # some basic summary statistics
#contains 2500 documents with 31,752 terms
#sparsity = 99% indicates we removed terms that only appear in at most 1% of the data
#maximal term length of 36 indicates that the largest number of characters within 1 term is 36


#dropping terms that only occur in one or two documents as there is nothing to learn if a term occurred once.
## Below removes those terms that have count 0 in >99% of docs.  
DTM_test = removeSparseTerms(DTM_test, 0.99)
DTM_test # now ~ 3,325 #MAYBE ADJUST THIS LATER 
DTM_test1 <- as.matrix(DTM_test)



## ADD a filler word to DTM_train to fill with new words in test set 

#words in train DTM:
train_words <- colnames(DTM_train1)
test_words <- colnames(DTM_test1)

#finding words that are in test but not train
new_words = setdiff(test_words,train_words) 
length(new_words)#398 new words
length(test_words) #3370 total words 

filler <- c(new_words) #this currently has all new words in test 

new_wordsDF = DTM_test1[,filler]
totalnew <- rowSums(new_wordsDF) #vector for the test set 
# with  how many words are 'new' for each test document.

# sampling with replacement to get the train 'filler' vector. provides degree of randomization 
filler_vector <- sample(totalnew, 2500, replace = TRUE)

#create a dataframe just new "filler" words
test_words <- data.frame(filler_vector)  

#combined DTM matrix 
test_trainDTM <- cbind(DTM_train1, test_words)

## continuing to pre-process the test set 

#the DTM for the test set contains the words that are not in the train set
#we need to take these words and they're associated rows out of the test set
#and instead replace it with our filler vector: a vector containing how many words are new for each test document 
#we had used a randomly sampled version of this vector in our training set 

#filler is a vector of the words in test but not in train 
`%ni%` <- Negate(`%in%`) #setting this tool to find ones that are not in another list 
DTM_test1 <- as.data.frame(DTM_test1) #turning test DTM matrix into a dataframe 
DTM_test2 <- DTM_test1[,which(names(DTM_test1) %ni% filler)] #creating a dataframe with words that are in train 

#sanity check: there were 3370 total words in test DTM. We found 398 new words. This data frame should have 
#2972 columns (new words)
if(length(names(DTM_test2))==2972){print("yay success!")}

#total new contained the count of new words for each test document. I cbind this to DTM_test2 to account for presence of new words
#the training DTM matrix contained a randomized sample of these words so that the models were not trained w exactly the same words
#that are in the test set 

#create a dataframe just count of "new" "filler" words
test_not_new_words <- data.frame(totalnew)  

#combined test DTM matrix 
test_DTM <- cbind(DTM_test2, test_not_new_words)

#calculating TF-IDF for test matrix

y_test <- factor(vector_test) #response vector as name of author

Ntest = nrow(test_DTM)
Dtest = ncol(test_DTM)
# TF weights
TF_mattest = test_DTM /rowSums(test_DTM)

# IDF weights
IDF_vectest = log(1 + N/colSums(test_DTM  > 0))

# TF-IDF weights:
# use sweep to multiply the columns (margin = 2) by the IDF weights
TFIDF_mattest = sweep(TF_mattest, MARGIN=2, STATS=IDF_vectest, FUN="*")  

# spot check an entry
TF_mattest[5, 224]
IDF_vectest[224]
TFIDF_mattest[5,224] == TF_mattest[5, 224] * IDF_vectest[224]




######
### APPROACH 1: PCA ON TF-IDF WEIGHTS
#####


N = nrow(test_trainDTM)
D = ncol(test_trainDTM)
# TF weights
TF_mat = test_trainDTM /rowSums(test_trainDTM)

# IDF weights
IDF_vec = log(1 + N/colSums(test_trainDTM  > 0))

# TF-IDF weights:
# use sweep to multiply the columns (margin = 2) by the IDF weights
TFIDF_mat = sweep(TF_mat, MARGIN=2, STATS=IDF_vec, FUN="*")  

# spot check an entry
TF_mat[5, 224]
IDF_vec[224]
TFIDF_mat[5,224] == TF_mat[5, 224] * IDF_vec[224]

y <- factor(vector_train) #response vector as name of author


### PCA on the TF-IDF weights with 10 PCS
pc_train10 = prcomp(TFIDF_mat, rank=10, scale=TRUE)
loadings = pc_train10$rotation
dim(loadings) #3326 rows with 10 PCs.. expected
scores = pc_train10$x #location
summary(pc_train10) #accounts for 5.48 percent of variation 

comp1 = order(loadings[,1], decreasing=TRUE)
colnames(TFIDF_mat)[head(comp1,25)] 
colnames(TFIDF_mat)[tail(comp1,25)] 
#first component contrasts political words (china/democracy/communism)
#with business words (stock/market/analyst/sales)

comp2 = order(loadings[,2], decreasing=TRUE)
colnames(TFIDF_mat)[head(comp2,25)] 
colnames(TFIDF_mat)[tail(comp2,25)] 
#2nd component contrasts factory (detroit/automaker/strike) 
#with business words (markets/growth/billion)

#merging author name with first 10 PCs
training10 = merge(y, pc_train10$x[,1:10], by="row.names")

#applying first 10 PC in multinomial regression
train_lm10 <- multinom(x ~ PC1+PC2+PC3+PC4+PC5+PC6+PC7+PC8+PC9+PC10, data = training10)
summary(train_lm10) #residual deviance: 7330.694

## interpreting train_lm10
#getting yhat predictions for train data
pred10 <- predict(train_lm10, newdata = training10, "class")

# Building classification table
ctable10 <- table(training10$x, pred)

# Calculating accuracy - sum of diagonal elements divided by total obs.. only about 52.32% accurate on train data
round((sum(diag(ctable10))/sum(ctable10))*100,2)

# predicted probabilities for authors
head(pp10 <- fitted(train_lm10))

### PCA on the TF-IDF weights with 25 PCS (takes a lot longer)
pc_train25 = prcomp(TFIDF_mat, rank=25, scale=TRUE)
loadings2 = pc_train25$rotation
dim(loadings2) #3326 rows with 25 PCs... expected
scores2 = pc_train25$x #location
summary(pc_train25) #25 PC account for 9.89% variation 

### look into what first 2 components indicate 
comp1_25 = order(loadings2[,1], decreasing=TRUE)
colnames(TFIDF_mat)[head(comp1_25,25)] 
colnames(TFIDF_mat)[tail(comp1_25,25)] 
#first component contrasts same as above

comp2_25 = order(loadings2[,2], decreasing=TRUE)
colnames(TFIDF_mat)[head(comp2_25,25)] 
colnames(TFIDF_mat)[tail(comp2_25,25)] 
#2nd component contrasts same as above

#merging author name with first 25 PCs
training25 = merge(y, pc_train25$x[,1:25], by="row.names")

#applying first 10 PC in multinomial regression
train_lm25 <- multinom(x ~ PC1+PC2+PC3+PC4+PC5+PC6+PC7+PC8+PC9+PC10+PC11+PC12+PC13+PC14
                       +PC15+PC16+PC17+PC18+PC19+PC20+PC21+PC22+PC23+PC24+PC25, 
                       data = training25, MaxNWts=1500)
summary(train_lm25) 

## interpreting train_lm25
#getting yhat predictions for train data
pred25 <- predict(train_lm25, newdata = training25, "class")

# Building classification table
ctable25 <- table(training25$x, pred)

# Calculating accuracy - sum of diagonal elements divided by total obs.. about 77.6% accurate.. a lot better on train
round((sum(diag(ctable25))/sum(ctable25))*100,2) #inc number of PC's does help! 

# predicted probabilities for authors
head(pp25 <- fitted(train_lm25))

### Looking at 40 components! 
### PCA on the TF-IDF weights with 40 PCS (takes a lot longer)
pc_train40 = prcomp(TFIDF_mat, rank=40, scale=TRUE)
loadings40 = pc_train40$rotation
dim(loadings40) #3326 rows with 40 PCs... expected
scores40 = pc_train40$x #location
summary(pc_train40) #40 PC account for 13.263% variation 

### look into what first 2 components indicate 
comp1_40 = order(loadings40[,1], decreasing=TRUE)
colnames(TFIDF_mat)[head(comp1_40,25)] 
colnames(TFIDF_mat)[tail(comp1_40,25)] 
#first component contrasts same as above

comp2_40 = order(loadings40[,2], decreasing=TRUE)
colnames(TFIDF_mat)[head(comp2_40,25)] 
colnames(TFIDF_mat)[tail(comp2_40,25)] 
#2nd component contrasts same as above

#merging author name with first 25 PCs
training40 = merge(y, pc_train40$x[,1:40], by="row.names")

#applying first 10 PC in multinomial regression
train_lm40 <- multinom(x ~ PC1+PC2+PC3+PC4+PC5+PC6+PC7+PC8+PC9+PC10+PC11+PC12+PC13+PC14
                       +PC15+PC16+PC17+PC18+PC19+PC20+PC21+PC22+PC23+PC24+PC25+PC26+PC27+PC28+PC29+PC30+PC31+PC32+PC33+PC34
                       +PC35+PC36+PC37+PC38+PC39+PC40,
                       data = training40, MaxNWts=2200)
summary(train_lm40) 

## interpreting train_lm25
#getting yhat predictions for train data
pred40 <- predict(train_lm40, newdata = training40, "class")

# Building classification table
ctable40 <- table(training40$x, pred40)

# Calculating accuracy - sum of diagonal elements divided by total obs.. about 91.24% accurate.. a lot better on train
#but at a cost to computation speed
round((sum(diag(ctable40))/sum(ctable40))*100,2) #inc number of PC's does help! 

# predicted probabilities for authors
head(pp40 <- fitted(train_lm40))


### ANALYZING HOW EACH OF THESE MODELS WORKED ON TEST DATA SET

#before doing this.. notice the TFIDF matrix for training data has 3326 words while the test TFIDF has 2973
#this is because we removed all new words from the test dataset. In order to apply the PC of train to test, we need to
#add in all the words that are in train and not in test to the test set and give them a tfidf count of 0 as they do not appear at all

#we need to set the last column containing count of new words in test data set to be of the same name as train.. filler_vector
names(TFIDF_mattest)[length(names(TFIDF_mattest))]<-"filler_vector" 

tfidf_train <- colnames(TFIDF_mat)
tfidf_test <- colnames(TFIDF_mattest)
words2add = c(setdiff(tfidf_train,tfidf_test)) #creating a vector of the words that are different between 2 sets


colnames(baskets.team) <-


#creating a matrix of 0 with 2500 rows and number of columns equal to number of new words 2 add 
words2add_matrix <- matrix(0, 2500, length(words2add)) 
#create this into a dataframe
words2addDF <- data.frame(words2add_matrix) 
#specifying the col names as words in train that will be added to test 
colnames(words2addDF) <- words2add

#combined test TFIDF dataframe
TFIDF_test <- cbind(TFIDF_mattest, words2addDF)


'''
test_results10 <-predict(train_lm10, newdata = test.matrix, "probs")

pc_test10 = prcomp(test.matrix, rank=10, scale=TRUE) #need PC to predict?? applying same weights to different PCs
test10 = merge(y_test, pc_test10$x[,1:10], by="row.names")
pc_test25 = prcomp(test.matrix,rank=25,scale=TRUE)
test25 = merge(y_test, pc_test25$x[,1:25], by="row.names")


# Predicting the values for test dataset using model with 10 pcs
predtest10 <- predict(train_lm10, newdata = test10, "class")
# Building classification table
ctable_test10 <- table(test10$x, predtest10)
# Calculating accuracy - sum of diagonal elements divided by total obs.. only 1.88% accurate??
round((sum(diag(ctable_test10))/sum(ctable_test10))*100,2)

# Predicting the values for test using model with 25 pcs
predtest25 <- predict(train_lm25, newdata = test25, "class")
# Building classification table
ctable_test25 <- table(test25$x, predtest25)
# Calculating accuracy - sum of diagonal elements divided by total obs.. only 2.44% accurate??
round((sum(diag(ctable_test25))/sum(ctable_test25))*100,2)
'''

###transform test TFIDF into training PCA

#for 10 PC
test.data10 <- predict(pc_train10, newdata = TFIDF_test)
test.data10 <- as.data.frame(test.data10)
test10 = merge(y_test, test.data10, by="row.names") #merging PC with actual authors

#make multinomial prediction on test data
pred10 <- predict(train_lm10, test10[,3:12], "class") #grabbing class predictions (author predictions)

# Building classification table
ctable_test10 <- table(test10$x, pred10)
# Calculating accuracy - sum of diagonal elements divided by total obs.. 37.88% accurate
round((sum(diag(ctable_test10))/sum(ctable_test10))*100,2)


#for 25 PC
test.data25 <- predict(pc_train25, newdata = TFIDF_test)
test.data25 <- as.data.frame(test.data25)
test25 = merge(y_test, test.data25, by="row.names") #merging PC with actual authors

#make multinomial prediction on test data
pred25 <- predict(train_lm25, test25[,3:27], "class") #grabbing class predictions (author predictions)

# Building classification table
ctable_test25 <- table(test25$x, pred25)
# Calculating accuracy - sum of diagonal elements divided by total obs.. 49.4% accurate
round((sum(diag(ctable_test25))/sum(ctable_test25))*100,2)


#for 10 PC
test.data40 <- predict(pc_train40, newdata = TFIDF_test)
test.data40 <- as.data.frame(test.data40)
test40 = merge(y_test, test.data40, by="row.names") #merging PC with actual authors

#make multinomial prediction on test data
pred40 <- predict(train_lm40, test40[,3:42], "class") #grabbing class predictions (author predictions)

# Building classification table
ctable_test40 <- table(test40$x, pred40)
# Calculating accuracy - sum of diagonal elements divided by total obs.. 50.28 accurate
round((sum(diag(ctable_test40))/sum(ctable_test40))*100,2)


## so in conclusion working with 25 PC does a good enough job.. 40 does only slightly better but is more computationally 
#expensive





