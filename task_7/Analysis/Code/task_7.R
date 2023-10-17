## task_7.R

## Gizem Kilicgedik 	October 17, 2023

## This is the r script for the Task 7. In this task, we analyze the speeches by U.S. senators in the 105th Congress (1997-1998).

## Setting up the packages

library(tm)
library(tidytext)
library(dplyr)
library(tidyr)
library(ggplot2)
library(stringr)
library(stringi)
library(wordcloud)
library(slam)
library(SparseM)
library(e1071)
library(reshape2)


### 1.Load Data

# Loading all files into a corpus using "tm".'

dir_path <- "/Users/gizemkilicgedik/Documents/GitHub/AppliedEmpirical/task_7/Raw/Data/105_extracted_date"
senator_corpus <- VCorpus(DirSource(dir_path))
senator_corpus


# Turn the data into a tibble - tokenization

senators_td = senator_corpus %>%
  tidy() %>%
  select(id, text) %>%
  mutate(id = str_match(id, "-(.*).txt")[,2]) %>%
  unnest_tokens(word, text) %>% 
  group_by(id) %>%
  mutate(row=row_number()) %>%
  ungroup()

### 2.Pre-processing

# Loading the senator party labels.

sen105_party <- read.csv("/Users/gizemkilicgedik/Documents/GitHub/AppliedEmpirical/task_7/Raw/Data/sen105_party.csv", stringsAsFactors = FALSE)

# Creating a data frame with senator names in lower case
names = sen105_party %>%
  mutate(word=tolower(lname)) %>%
  select(word)

# Creating a data frame with state names in lower case
states = as.data.frame(c(tolower(state.abb), tolower(state.name)))
colnames(states) <- "word"

# Combine names and states with lowercas in order to merge below
sen105_party_ = sen105_party %>%
  mutate(lname=tolower(lname), 
         stateab=tolower(stateab),
         id=str_c(lname,stateab, sep="-"))

# Removing non-alphabetic characters, stopwords, senator and state names 

droplist = c("text","doc","docno")
senators_td = senators_td %>% 
  mutate(word = str_extract(word, "[a-z']+")) %>%
  drop_na(word)   %>%
  filter(!(word %in% droplist)) %>% 
  anti_join(stop_words) %>%
  anti_join(names) %>%
  anti_join(states)

# Creating biagrams
senators_bigram = senators_td %>%
  arrange(id,row) %>%
  group_by(id) %>%
  mutate(bigram = str_c(lag(word,1), word, sep = " ")) %>%
  filter(row == lag(row,1)+1) %>%
  select(-word) %>%
  ungroup()

#Creating trigrams
senators_trigram = senators_td %>%
  arrange(id,row) %>%
  group_by(id) %>%
  mutate(trigram = str_c(lag(word,2), lag(word,1),  word, sep = " ")) %>%
  filter(row == lag(row,1)+1 & lag(row,1) == lag(row,2)+1) %>%
  select(-word) %>%
  ungroup()

### 3.Simple Analysis

## 3.a - Compute overall frequency lists for bigrams and trigrams.

#Create an overall word-frequency list

wordlist = senators_td %>%
  count(word, sort = TRUE)

bigramlist = senators_bigram %>%
  count(bigram, sort = TRUE)

trigramlist = senators_trigram %>%
  count(trigram, sort = TRUE)

## The most frequent biagram is "unanimous consent", the most frequent triagram is "balanced budget amendment".

# List 50 most frequent words, bigrams and trigrams

wordlist %>% 
  filter(row_number()<50) %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(word,n)) + 
  geom_bar(stat = "identity") + 
  xlab(NULL) + 
  coord_flip()

bigramlist %>% 
  filter(row_number()<50) %>%
  mutate(bigram = reorder(bigram, n)) %>%
  ggplot(aes(bigram,n)) + 
  geom_bar(stat = "identity") + 
  xlab(NULL) + 
  coord_flip()

trigramlist %>% 
  filter(row_number()<50) %>%
  mutate(bigram = reorder(trigram, n)) %>%
  ggplot(aes(trigram,n)) + 
  geom_bar(stat = "identity") + 
  xlab(NULL) + 
  coord_flip()

# Use lists to plot word frequency graph

word_plot <- wordlist %>%
  filter(row_number() < 50) %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(word, n)) + 
  geom_bar(stat = "identity") + 
  xlab(NULL) + 
  coord_flip()

# Plot bigram frequency graph
bigram_plot <- bigramlist %>%
  filter(row_number() < 50) %>%
  mutate(bigram = reorder(bigram, n)) %>%
  ggplot(aes(bigram, n)) + 
  geom_bar(stat = "identity") + 
  xlab(NULL) + 
  coord_flip()

# Plot trigram frequency graph
trigram_plot <- trigramlist %>%
  filter(row_number() < 50) %>%
  mutate(trigram = reorder(trigram, n)) %>%
  arrange(desc(n)) %>% 
  ggplot(aes(trigram, n)) + 
  geom_bar(stat = "identity") + 
  xlab(NULL) + 
  coord_flip()



## 3.b - Merge in party information. Compute frequency lists for bigrams and trigrams by party.//
# // Plot a wordcloud for the 50 words most frequently used by each party.

# Frequency list of words by party

wordlist_party = senators_td %>% 
  inner_join(sen105_party_) %>%
  count(party, word, sort=TRUE) %>%
  group_by(party) %>% 
  mutate(share = n / sum(n), ran=row_number()) %>%
  ungroup()

# Frequency list bigram

bigramlist_party = senators_bigram %>% 
  inner_join(sen105_party_) %>%
  count(party, bigram, sort=TRUE) %>%
  group_by(party) %>% 
  mutate(share = n / sum(n), ran=row_number()) %>%
  ungroup()

# Frequency list trigram

trigramlist_party = senators_trigram %>% 
  inner_join(sen105_party_) %>%
  count(party, trigram, sort=TRUE) %>%
  group_by(party) %>% 
  mutate(share = n / sum(n), ran=row_number()) %>%
  ungroup()

# Wordcloud by party 

wordlist_party %>%
  select(word, party, n) %>%
  acast(word ~ party, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("pink", "brown"), 
                   max.words = 100,
                   random.order=FALSE)

### 4.Analysis: Estimate a Support Vector Machine model predicting the party of the senator based on bigrams.
### What bigrams are most important in predicting the party of the senator?

# Step 1: Compute bigram freuency, by senator

bigramfreq_s = senators_bigram %>% 
  inner_join(sen105_party_) %>%
  count(id, party, bigram, sort=TRUE) %>%
  ungroup()

# Step 2: Data managmememt for SVM analysis. Recode (by casting) bigramlist into a matrix object

x = bigramfreq_s %>%
  cast_sparse(id, bigram, n)
class(x) # matrix

# Data management: Order x-matrix to match y-vector

x = x[order(rownames(x)),]

# Data managememnt: code dependent variable y as factor 

y = sen105_party_[order(sen.party_$id),]
y = as.matrix(y$party)
y = as.factor(y)

# Step 3: Estimate SVM 
svmfit = svm(x, y, kernel="linear", cost=0.1)
summary(svmfit)

# Step 4:set tuning parameter 

set.seed(19940103)
tune.out = tune(svm, x, y, kernel="linear",
                ranges=list(cost=c(0.00001,
                                   0.001,
                                   0.01, 
                                   0.1, 
                                   1)))
summary(tune.out)

bestmod = tune.out$best.model 
ypred = predict(bestmod, x)
table(predict = ypred, truth=y)

# Step 5: retrieve beta coefficients 

beta = drop(t(bestmod$coefs)%*%as.matrix(x)[bestmod$index,])
beta = as.data.frame(beta)

# The 4 most important bigrams: unanimous consent, federal debt, debt stood, and balanced budget

## End of the document.




