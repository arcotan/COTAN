#' @details `cleanPlots()` creates the plots associated to the output of the
#'   [clean()] method.
#'
#' @param objCOTAN a `COTAN` object
#'
#' @returns `cleanPlots()` returns a `list` of `ggplot2` plots:
#'   * "pcaCells" is for pca cells,
#'   * "pcaCellsData" is the data of the pca cells,
#'   * "genes" is for cluster2 cells' group genes,
#'   * "UDE" is for cell UDE,
#'   * "nu" is for cell nu.
#'
#' @export
#'
#' @importFrom rlang set_names
#'
#' @importFrom tibble rownames_to_column
#' @importFrom tibble column_to_rownames
#'
#' @importFrom stats hclust
#' @importFrom stats cutree
#'
#' @importFrom utils head
#'
#' @importFrom Matrix t
#' @importFrom Matrix rowMeans
#' @importFrom Matrix colMeans
#'
#' @importFrom irlba prcomp_irlba
#'
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 geom_point
#' @importFrom ggplot2 geom_tile
#' @importFrom ggplot2 geom_hline
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 facet_grid
#' @importFrom ggplot2 ggtitle
#' @importFrom ggplot2 xlab
#' @importFrom ggplot2 ylab
#' @importFrom ggplot2 scale_color_gradient2
#' @importFrom ggplot2 scale_color_manual
#' @importFrom ggplot2 geom_label
#' @importFrom ggrepel geom_text_repel
#'
#' @importFrom graphics par
#' @importFrom graphics title
#'
#' @examples
#' # This creates many infomative plots useful to determine whether
#' # there is still something to drop...
#' # Here we use the tuple-like assignment feature of the `zeallot` package
#' c(pcaCellsPlot, ., genesPlot, UDEPlot, nuPlot ) %<-% cleanPlots(objCOTAN)
#' plot(pcaCellsPlot)
#' plot(UDEPlot)
#'
#' @rdname RawDataCleaning
#'
cleanPlots <- function(objCOTAN) {

  logThis("PCA: START", logLevel = 2L)

  rawNorm <- getNormalizedData(objCOTAN)

  pcaCells <- prcomp_irlba(t(rawNorm), n = 5L)[["x"]]
  rownames(pcaCells) <- getCells(objCOTAN)

  distCells <- stats::dist(scale(pcaCells), method = "euclidean") # mhalanobis

  pcaCells <- as.data.frame(pcaCells)

  logThis("PCA: DONE", logLevel = 2L)

  logThis("Hierarchical clustering: START", logLevel = 2L)

  hcCells <- hclust(distCells, method = "complete")
  rm(distCells)

  groups <- cutree(hcCells, k = 2L)

  pos1 <- which(groups == 1L)
  pos2 <- which(groups == 2L)

  # ensure "A" group is the most numerous
  if (length(pos1) < length(pos2)) {
    # swap pos1 <-> pos2
    pos3 <- pos1
    pos1 <- pos2
    pos2 <- pos3
  }

  groups[pos1] <- "A"
  groups[pos2] <- "B"

  pcaCells <- cbind(pcaCells, groups)

  logThis("Hierarchical clustering: DONE", logLevel = 2L)
  gc()

  toClust <- as.matrix(round(rawNorm, digits = 4L))

  assert_that(identical(colnames(toClust), names(groups)),
              msg = "Error in the cell names")

  # ---- next: to check which genes are specific for the B group of cells
  B <- set_names(as.data.frame(toClust[, pos2]), colnames(toClust)[pos2])

  rm(toClust)

  D <- data.frame("means" = rowMeans(B), "n" = NA)
  rownames(D) <- rownames(B)
  D <- rownames_to_column(D)
  rm(B)

  D <- D[order(D[["means"]], decreasing = TRUE), ]
  rownames(D) <- c()
  D <- column_to_rownames(D)

  D <- D[D[["means"]] > 0.0, ]
  D[["n"]] <- seq_along(D[["means"]])

  gc()

  #check if the pca plot is clean enough and from the printed genes,
  #if the smallest group of cells are characterized by particular genes

  pcaCellsPlot <- ggplot(subset(pcaCells, groups == "A"),
                         aes(x = PC1, y = PC2, colour = groups)) +
                  geom_point(alpha = 0.5, size = 3L) +
                  geom_point(data = subset(pcaCells, groups != "A"),
                             aes(x = PC1, y = PC2, colour = groups),
                             alpha = 0.8, size = 3L) +
                  scale_color_manual(groups, values = c("A" = "#8491B4B2",
                                                        "B" = "#E64B35FF")) +
                  plotTheme("pca")

  minN <- min(D[["n"]]) + 15.0
  lowD <- D[["n"]] < minN
  genesPlot <-  ggplot(D, aes(x = n, y = means)) +
                geom_point() +
                ggtitle(label = "B cell group genes mean expression"
                        #subtitle = " - B group NOT removed -"
                        ) +
                geom_label(data = subset(D, lowD),
                      aes(x = n, y = means, label = rownames(D)[lowD]),
                      #nudge_y = 0.05,
                      nudge_x = 400.0
                      #direction = "x",
                      #angle = 90.0,
                      #vjust = 0L,
                      #segment.size = 0.2
                      ) +
                plotTheme("genes") +
  theme(plot.title = element_text(hjust = 1.0),
        plot.subtitle = element_text(hjust = 0.95, vjust = -25.0))


  nuEst <- round(getNu(objCOTAN), digits = 7L)
  UDEPlot      <- ggplot(pcaCells, aes(x = PC1, y = PC2, colour = log(nuEst))) +
                  geom_point(size = 1L, alpha = 0.8) +
                  scale_color_gradient2(low = "#E64B35B2", mid = "#4DBBD5B2",
                                        high = "#3C5488B2",
                                        midpoint = log(mean(nuEst)),
                                        name = "ln(nu)") +
                  ggtitle("Cells PCA coloured by cells efficiency") +
                  plotTheme("UDE")

  nuDf <- data.frame("nu" = sort(getNu(objCOTAN)),
                     "n" = seq_len(getNumCells(objCOTAN)))
  nuPlot       <- ggplot(nuDf, aes(x = n, y = nu)) +
                  geom_point(colour = "#8491B4B2", size = 1L) +
                  plotTheme("common")

  return(list("pcaCells" = pcaCellsPlot, "pcaCellsData" = pcaCells,
              "genes" = genesPlot, "UDE" = UDEPlot, "nu" = nuPlot))
}
