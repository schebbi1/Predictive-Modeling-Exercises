dev.off()
rm(list=ls())

library(tidyverse)
library(arules)
library(arulesViz)
library(igraph)
library(data.table)

# reads groceries text file as transaction dataset
groceries = read.transactions(file = "https://raw.githubusercontent.com/jgscott/STA380/master/data/groceries.txt",
                          format = c("basket"), sep = ",")

arules::inspect(head(groceries))

# gathers most frequent items in dataset, filtered by decreasing support
FrequentItems = eclat(groceries, parameter = list(support = 0.05))
FrequentItems <- sort(FrequentItems, by = "support", decreasing = TRUE)
arules::inspect(head(FrequentItems, 15))

# plotting absolute frequency of top 15 items in dataset
itemFrequencyPlot(groceries, topN = 15, type = "absolute",
                  main = "Item Frequency")

# plotting relative frequency of top 15 items in dataset
itemFrequencyPlot(groceries, topN = 15, type = "relative",
                  main = "Item Frequency")

# 32791 rules created
groceryRules <- apriori(groceries, parameter = list(support = 0.001, confidence = 0.1))
arules::inspect(head(groceryRules))

# sorting grocery rules by decreasing support
rulesSupport <- sort(groceryRules, by = "support", decreasing = TRUE)
arules::inspect(head(rulesSupport, 15))

# sorting grocery rules by decreasing confidence
rulesConfidence <- sort(groceryRules, by = "confidence", decreasing = TRUE)
arules::inspect(head(rulesConfidence, 15))

# sorting grocery rules by decreasing lift
rulesLift <- sort(groceryRules, by = "lift", decreasing = TRUE)
arules::inspect(head(rulesLift, 15))


# There are 28 different association rules where confidence = 1. Notice that the support remains relatively low, hovering around 0.01.
# Lift for these rules tends to be about 4 or 5.
arules::inspect(subset(rulesConfidence, subset = confidence == 1))

# There are 20 different association rules where lift > 15. Notice that support is also relatively low, hovering around 0.01.
# Confidence ranges between 0.12 and 0.65.
arules::inspect(subset(rulesLift, subset = lift > 15))

# As seen from the inspection of subsets above, the consequent(s) of 100% confidence rules are 'whole milk' and 'other vegetables'.
# This makes sense seeing that people, in general, consume milk and vegetables often.
# The consequent(s) of high lift rules include liquor, instant food products, rice, hamburger meat, wine, and popcorn among others.


# The plot confirms what was stated above. Individual data points are shaded by confidence, and the most confidence occurs at low support
# and low to medium levels of lift. 
plot(groceryRules, measure = c("support", "lift"), shading = "confidence")

sub1 = subset(groceryRules, subset = confidence > 0.1 & support > 0.01)
arules::inspect(head(sub1))

# A graph of 50 rules, sorted by the highest lift based on the subset given above: confidence > 0.1 and support > 0.01.
plot(head(sub1, 50, by = 'lift'), method = 'graph')


# saved a graphml file containing 1084 nodes and 3907 edges of groceryRules.
# The file will be uploaded onto github and a screenshot of the gephi-produced graph will be uploaded.
# Some characteristics of the network are listed below.
# Network diameter =  14
# Graph Density    =  0.003
# Modularity       =  0.331
# Avg Path Length  =  4.537
saveAsGraph(head(groceryRules, n = 1000, by = "lift"), file = "groceryRules.graphml")

