library(tm)
library(SnowballC)
library(pdftools)
library(wordcloud)
library(ggplot2)
library(plyr)
library(class)
Sys.setlocale("LC_CTYPE", "russian")

#функция предварительной обработки корпуса документов
preprocessing <- function(doc_corpus) {
  doc_corpus <- tm_map(doc_corpus, removePunctuation)
  doc_corpus <- tm_map(doc_corpus, removeNumbers) #В БУДУЩЕМ МОЖЕТ НЕ ПОНАДОБИТСЯ!!!
  doc_corpus <- tm_map(doc_corpus, stripWhitespace) #удаление пробелов
  doc_corpus <- tm_map(doc_corpus, content_transformer(scan_tokenizer))
  doc_corpus <- tm_map(doc_corpus, content_transformer(function(x) {x <- wordStem(x, language = "ru")}))
  doc_corpus <- tm_map(doc_corpus, content_transformer(tolower)) #содержимое в нижний регистр
  doc_corpus <- tm_map(doc_corpus, removeWords, stopwords("russian"))
  return(doc_corpus)
}

cname1 <- file.path("D:/RProjects/LawRobot/training/osparivanie deistvii/")
docs1 <- Corpus(DirSource(cname1), readerControl=list(reader=readPDF))
meta(docs1, "class") <- "FSSP"
docs1 <- preprocessing(docs1)

cname2 <- file.path("D:/RProjects/LawRobot/training/osparivanie reshenii/")
docs2 <- Corpus(DirSource(cname2), readerControl=list(reader=readPDF))
meta(docs2, "class") <- "FAS"
docs2 <- preprocessing(docs2)

cname3 <- file.path("D:/RProjects/LawRobot/training/postavka/")
docs3 <- Corpus(DirSource(cname3), readerControl=list(reader=readPDF))
meta(docs3, "class") <- "POSTAVKI"
docs3 <- preprocessing(docs3)

cname4 <- file.path("D:/RProjects/LawRobot/training/privlichenie/")
docs4 <- Corpus(DirSource(cname4), readerControl=list(reader=readPDF))
meta(docs4, "class") <- "LICENZIYA"
docs4 <- preprocessing(docs4)

wordcloud(docs1, min.freq = 1, scale = c(5, 0.3), max.words = 100, random.order = FALSE, rot.per = 0.15, colors = brewer.pal(8, "Dark2"))
wordcloud(docs2, min.freq = 1, scale = c(5, 0.3), max.words = 100, random.order = FALSE, rot.per = 0.15, colors = brewer.pal(9, "Set1"))
wordcloud(docs3, min.freq = 1, scale = c(5, 0.3), max.words = 100, random.order = FALSE, rot.per = 0.15, colors = brewer.pal(8, "Dark2"))
wordcloud(docs4, min.freq = 1, scale = c(5, 0.3), max.words = 100, random.order = FALSE, rot.per = 0.15, colors = brewer.pal(9, "Set1"))

createDF <- function(tdm, category) {
  doc_mat <- t(data.matrix(tdm))
  doc_df <- as.data.frame(doc_mat)
  doc_df$doccategory <- category
  return(doc_df)
}

#создание дата-фреймов и ТДМ, фильтр признаков (!!! нужно будет доработать)
FSSP_tdm <- TermDocumentMatrix(docs1)
FSSP_tdm <- removeSparseTerms(FSSP_tdm, 1 - (37/length(docs1)))
FSSP_tdm
FSSP_df <- createDF(FSSP_tdm, "FSSP")

FAS_tdm <- TermDocumentMatrix(docs2)
FAS_tdm <- removeSparseTerms(FAS_tdm, 1 - (31/length(docs2)))
FAS_tdm
FAS_df <- createDF(FAS_tdm, "FAS")

POSTAVKI_tdm <- TermDocumentMatrix(docs3)
POSTAVKI_tdm <- removeSparseTerms(POSTAVKI_tdm, 1 - (57/length(docs3)))
POSTAVKI_tdm
POSTAVKI_df <- createDF(POSTAVKI_tdm, "POSTAVKI")

LICENZIYA_tdm <- TermDocumentMatrix(docs4)
LICENZIYA_tdm <- removeSparseTerms(LICENZIYA_tdm, 1 - (34/length(docs4)))
LICENZIYA_tdm
LICENZIYA_df <- createDF(LICENZIYA_tdm, "LICENZIYA")

dfStack <- rbind.fill(FSSP_df, FAS_df, POSTAVKI_df, LICENZIYA_df)
dfStack[is.na(dfStack)] <- 0

#разбивка выборки на обучение и тест
indTrain <- sample(nrow(dfStack), ceiling(nrow(dfStack) * 0.7))
indTest <- (1:nrow(dfStack))[-indTrain]
dType <- dfStack[, "doccategory"]
alldata <- dfStack[, !colnames(dfStack) %in% "doccategory"]

KNNprediction <- knn(alldata[indTrain, ], alldata[indTest, ], dType[indTrain])

confusionMat <- table(predicted = KNNprediction, Actual = dType[indTest])
confusionMat
accuracy <- sum(diag(confusionMat))/(length(indTest))
print(accuracy)

#загрузка и проверка реальной выборки (одного файла), вывод метки класса

go <- function(new_doc){
  #new_doc <- file.choose(new = FALSE) #запуск интерактивного окна выбора файла
  docs_new <- Corpus(URISource(new_doc), readerControl=list(reader=readPDF))
  docs_new <- preprocessing(docs_new)
  new_tdm <- TermDocumentMatrix(docs_new) 
  new_doc_df <- as.data.frame(t(data.matrix(new_tdm)))
  
  #Left outer join
  alldata_test <- alldata * 0
  inter <- intersect(colnames(alldata_test), colnames(new_doc_df))
  inter_new_doc_df <- new_doc_df[ , inter]
  new_data <- merge(x=alldata_test, y=inter_new_doc_df, by=inter, all.y=TRUE)
  new_data[is.na(new_data)] <- 0
  
  new_prediction <- knn(alldata[indTrain, ], new_data, dType[indTrain])
  new_prediction
  return(as.character(new_prediction))
}

