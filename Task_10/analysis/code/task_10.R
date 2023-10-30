rm(list = ls())
install.packages("terra")
install.packages("tidyterra")
install.packages("ggplot2")
install.packages("sp")
install.packages("sf")
library(terra)
library(tidyterra)
library(ggplot2)
library(sp)
library(sf)

setwd("C:/Users/gi.5199/Desktop/second_year/applied_empirical_economics/Task_10")



assign("indir", "01 Build/01 Input", envir = .GlobalEnv)
assign("outdir", "01 Build/03 Output", envir = .GlobalEnv)

k1 <- file.path("raw/Kommun_RT90_region.shp")

kommuns <- st_read(k1)

class(kommuns)

crs_kommuns <- st_crs(kommuns)
crs_kommuns

plot(kommuns)

plot_filepath <- file.path("kommuns.png")

r1 <- file.path("raw/jl_riks.shp")

rail <- st_read(r1)

class(rail)

crs_rail <- st_crs(rail)
crs_rail

plot(rail)

rail_reprojected <- st_transform(rail, crs = crs_kommuns)

plot(kommuns, col = "pink")
plot(rail_reprojected, add = TRUE, col = "brown" )