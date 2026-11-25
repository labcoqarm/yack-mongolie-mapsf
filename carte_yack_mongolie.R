# Démographie du yack en Mongolie : évolution 2013-2023 et effectifs 2023 par région (aimag)
# Sources : National Statistics Office of Mongolia (2024), geoBoundaries via Humanitarian Data Exchange (2021), OpenDataSoft (2019)
# Auteur : Armand Lecoq, 2024 (cours de cartographie et géovisualisation, M1 Géomatique)
# Lancer depuis le projet RStudio : la carte est écrite dans figures/carte_yack_mongolie.png

library(here)
library(sf)
library(dplyr)
library(mapsf)

# Projection azimutale équivalente de Lambert centrée sur la Mongolie : surfaces et échelle justes
crsMongolie <- "+proj=laea +lat_0=47 +lon_0=103 +datum=WGS84 +units=m +no_defs"

# 1. Import des données

tabYack <- read.csv(here("Donnees", "YackMongolie.csv"), fileEncoding = "UTF-8-BOM")
# Dornogovi : 0,1 et 1,2 yack dans la source, valeurs impossibles mises à NA
tabYack[tabYack$ISOcodes == "MN-063", c("TotalYack.2013", "TotalYack.2023")] <- NA
regMongolie <- st_read(here("Donnees", "geoBoundaries-MNG-ADM1.geojson"), quiet = TRUE)
mondeFond <- st_read(here("Donnees", "world-administrative-boundaries.geojson"), quiet = TRUE)

# 2. Préparation

# Asie et Europe suffisent pour le fond, et évitent de projeter l'autre face du globe
regMongolie <- st_transform(regMongolie, crsMongolie)
mondeFond <- mondeFond |>
  filter(continent %in% c("Asia", "Europe")) |>
  st_transform(crsMongolie)

# Centroïde de chaque aimag, joint au tableau pour placer les cercles
centroRegMong <- regMongolie |>
  st_centroid() |>
  select(shapeISO)
tabYack <- merge(tabYack, centroRegMong, by.x = "ISOcodes", by.y = "shapeISO") |>
  st_as_sf()

# Taux d'évolution 2013-2023, calculé seulement là où l'effectif 2013 atteint 1 000 yacks
seuil <- 1000
tabYack <- tabYack |>
  mutate(TxEvol = if_else(TotalYack.2013 >= seuil, (TotalYack.2023 - TotalYack.2013) / TotalYack.2013 * 100, NA))
txEvol <- st_drop_geometry(tabYack)[c("ISOcodes", "TxEvol")]
regMongolie <- merge(regMongolie, txEvol, by.x = "shapeISO", by.y = "ISOcodes")

# Point au centre de la Mongolie, pour la mappemonde de localisation
pointLocMong <- regMongolie |>
  st_union() |>
  st_centroid()

# Positions des légendes, en proportion de l'emprise de la Mongolie
emprise <- st_bbox(regMongolie)
larg <- emprise[["xmax"]] - emprise[["xmin"]]
haut <- emprise[["ymax"]] - emprise[["ymin"]]

# 3. Carte

dir.create(here("figures"), showWarnings = FALSE)
mf_theme("base", title_pos = "center", title_tab = TRUE)
mf_png(regMongolie, filename = here("figures", "carte_yack_mongolie.png"), width = 1400, res = 120, expandBB = c(0, 0, 0.06, 0))

# Premier calque : pays voisins en gris, cadrés sur la Mongolie, puis voile blanc pour la faire ressortir
mf_map(mondeFond, col = "lightgrey", border = "black", extent = regMongolie, expandBB = c(0, 0, 0.06, 0), add = FALSE)
mf_map(st_as_sfc(st_bbox(mondeFond)), col = "#FFFFFF99", border = "black", add = TRUE)
mf_shadow(regMongolie, col = "black", cex = 1, add = TRUE)

# Aplats : taux d'évolution 2013-2023, une classe de baisse et trois de hausse (couleurs BrBG), gris sous le seuil
mf_map(regMongolie, var = "TxEvol", type = "choro", breaks = c(-25, 0, 50, 100, 170), pal = c("#5ab4ac", "#f6e8c3", "#d8b365", "#8c510a"), col_na = "#9e9e9e", leg_no_data = "Moins de 1 000 yacks en 2013", border = "white", leg_pos = c(emprise[["xmin"]] + 0.5 * larg, emprise[["ymax"]] + 0.03 * haut), leg_size = 1, leg_val_rnd = 0, leg_title = "Taux (%) d'évolution du nombre de yacks entre 2013 et 2023", leg_horiz = TRUE, add = TRUE)

# Cercles proportionnels : nombre de yacks en 2023
mf_map(filter(tabYack, !is.na(TotalYack.2023)), var = "TotalYack.2023", type = "prop", inches = 0.5, col = "#8ea2c699", border = "black", leg_pos = c(emprise[["xmax"]] - 0.15 * larg, emprise[["ymin"]] + 0.34 * haut), leg_title = "Nombre de yacks en 2023", leg_title_cex = 0.65, add = TRUE)

mf_label(tabYack, var = "Region", cex = 0.7, font = 1, col = "white", halo = TRUE, bg = "black", overlap = FALSE, lines = TRUE)

# Mappemonde de localisation en haut à gauche
mf_inset_on(x = "worldmap", pos = "topleft", cex = 0.12)
mf_worldmap(pointLocMong, col = "red", water_col = "lightblue", land_col = "lightgrey")
mf_inset_off()

mf_layout(title = "Démographie du yack par région (aimag) en Mongolie", credits = "Auteur : A. Lecoq, 2024\nSources : National Statistics Office of Mongolia (2024), geoBoundaries / Humanitarian Data Exchange (2021), OpenDataSoft (2019)", scale = TRUE, arrow = FALSE, frame = TRUE)
mf_arrow(pos = "topright") # flèche du nord à droite, la mappemonde occupe le coin gauche
dev.off()
