tm = tempdir()
stopifnot(file.exists(tm))

library(zeallot)

coexPoint <- function(o, e, n) {
  num <- ( ((o[1] - e[1]) / max(1, e[1])) - ((o[2] - e[2]) / max(1, e[2]))
         - ((o[3] - e[3]) / max(1, e[3])) + ((o[4] - e[4]) / max(1, e[4])) )
  den <- sqrt(n * ( (1 / max(1, e[1])) + (1 / max(1, e[2]))
                  + (1 / max(1, e[3])) + (1 / max(1, e[4])) ))
  return(num/den)
}

coexMatrix <- function(obs, exp, n, s) {
  coex <- matrix(NA, s, s)
  for (i in c(1:s)) for (j in c(i:s)) {
    o <- c(obs[[1]][i,j], obs[[2]][i,j], obs[[3]][i,j], obs[[4]][i,j])
    e <- c(exp[[1]][i,j], exp[[2]][i,j], exp[[3]][i,j], exp[[4]][i,j])
    coex[i,j] <- coexPoint(o, e, n)
  }
  return(as.matrix(forceSymmetric(coex)))
}

test_that("Calculations on genes", {
  raw <- matrix(c(1,0,4,2,11,0,6,7,0,9,10,8,0,0,0,3,0,0,2,0),
                nrow = 10, ncol = 20)
  rownames(raw) = LETTERS[1:10]
  colnames(raw) = letters[1:20]

  obj <- COTAN(raw = raw)
  obj <- clean(obj)

  mu <- calculateMu(obj)

  expect_equal(dim(mu), dim(getRawData(obj)))
  expect_equal(mu[ 1,  1], getLambda(obj)[ 1] * getNu(obj)[ 1],
               ignore_attr = TRUE)
  expect_equal(mu[10,  1], getLambda(obj)[10] * getNu(obj)[ 1],
               ignore_attr = TRUE)
  expect_equal(mu[ 1, 20], getLambda(obj)[ 1] * getNu(obj)[20],
               ignore_attr = TRUE)
  expect_equal(mu[10, 10], getLambda(obj)[10] * getNu(obj)[10],
               ignore_attr = TRUE)

  c(observedYY, observedY) %<-%
    observedContingencyTablesYY(obj, actOnCells = FALSE, asDspMatrices = FALSE)

  expect_s4_class(observedYY, "dsyMatrix")
  expect_equal(dim(observedYY), rep(getNumGenes(obj), 2))
  expect_equal(diag(as.matrix(observedYY)), observedY)
  expect_equal(length(observedY), getNumGenes(obj))
  expect_equal(observedY, c(20, rep(10 ,9)), ignore_attr = TRUE)

  observed <- observedContingencyTables(obj, actOnCells = FALSE,
                                        asDspMatrices = FALSE)
  c(observedNN, observedNY, observedYN, .) %<-% observed

  expect_equal(unlist(lapply(c(observedNN, observedNY, observedYN), dim)),
               rep(dim(observedYY), 3))
  expect_equal(diag(as.matrix(observedNN)), c(0, rep(10, 9)),
               ignore_attr = TRUE)
  expect_equal(observedNY, t(observedYN))
  expect_equal(diag(as.matrix(observedNY)), rep(0, 10), ignore_attr = TRUE)
  expect_equal(as.matrix(observedNN + observedNY + observedYN + observedYY),
               matrix(getNumCells(obj), nrow = getNumGenes(obj),
                      ncol = getNumGenes(obj)),
               ignore_attr = TRUE)

  obj <- estimateDispersionBisection(obj, cores = 4, chunkSize = 4)

  c(expectedNN, expectedN) %<-%
    expectedContingencyTablesNN(obj, actOnCells = FALSE, asDspMatrices = TRUE)

  expect_s4_class(expectedNN, "dspMatrix")
  expect_equal(dim(expectedNN), rep(getNumGenes(obj), 2))
  expect_equal(length(expectedN), getNumGenes(obj))
  expect_equal(expectedN, c(0, rep(10, 9)),
               ignore_attr = TRUE, tolerance = 1e-4)

  expected <- expectedContingencyTables(obj, actOnCells = FALSE,
                                        asDspMatrices = TRUE)
  c(., expectedNY, expectedYN, expectedYY) %<-% expected

  expect_equal(substring(names(observed),9), substring(names(expected), 9))
  expect_equal(unlist(lapply(c(expectedYY, expectedNY, expectedYN), dim)),
               rep(dim(expectedNN), 3))
  expect_equal(as.matrix(expectedNN + expectedNY + expectedYN + expectedYY),
               matrix(getNumCells(obj), nrow = getNumGenes(obj),
                      ncol = getNumGenes(obj)),
               ignore_attr = TRUE)

  # take a gene pair ensuring to poll only the upper triangle side of the
  # matrices as the flag 'asDspMatrices = TRUE' makes them incorrect on the
  # other side
  e1 <- sample(10, 1); e2 <- sample(10, 1)
  g1 <- getGenes(obj)[min(e1, e2)]
  g2 <- getGenes(obj)[max(e1, e2)]
  c(gpObs, gpExp) %<-% contingencyTables(obj, g1, g2)

  expect_equal(as.vector(gpObs), c(observedYY[g1, g2], observedYN[g1, g2],
                                   observedNY[g1, g2], observedNN[g1, g2]))
  expect_equal(as.vector(gpExp), c(expectedYY[g1, g2], expectedYN[g1, g2],
                                   expectedNY[g1, g2], expectedNN[g1, g2]))

  obj <- calculateCoex(obj, actOnCells = FALSE, optimizeForSpeed = FALSE)

  expect_equal(dim(getGenesCoex(obj)), rep(getNumGenes(obj), 2))
  expect_equal(getGenesCoex(obj)[1,1], 0)
  expect_equal(abs(as.vector(getGenesCoex(obj, zeroDiagonal = FALSE)[-1,-1])),
               rep(1, 81), tolerance = 0.01)

  expect_equal(as.matrix(getGenesCoex(obj, zeroDiagonal = FALSE)),
               coexMatrix(observed, expected,
                          getNumCells(obj), getNumGenes(obj)),
               tolerance = 0.001, ignore_attr = TRUE)

  expect_equal(getMetadataDataset(obj)[[1]], datasetTags()[c(5,6,7)],
               ignore_attr = TRUE)
  expect_equal(getMetadataElement(obj, datasetTags()[["gbad"]]), paste0(10/55))
})


test_that("Calculations on cells", {
  raw <- matrix(c(1,0,4,2,11,0,6,7,0,9,10,8,0,0,0,3,0,0,2,0),
                nrow = 10, ncol = 20)
  rownames(raw) = LETTERS[1:10]
  colnames(raw) = letters[1:20]

  obj <- COTAN(raw = raw)
  obj <- clean(obj)

  c(observedYY, observedY) %<-%
    observedContingencyTablesYY(obj, actOnCells = TRUE, asDspMatrices = TRUE)

  expect_s4_class(observedYY, "dspMatrix")
  expect_equal(dim(observedYY), rep(getNumCells(obj), 2))
  expect_equal(diag(as.matrix(observedYY)), observedY)
  expect_equal(length(observedY), getNumCells(obj))
  expect_equal(observedY, rep(c(7,4), 10), ignore_attr = TRUE)

  observed <- observedContingencyTables(obj, actOnCells = TRUE,
                                        asDspMatrices = TRUE)
  c(observedNN, observedNY, observedYN, .) %<-% observed

  expect_equal(unlist(lapply(c(observedNN, observedNY, observedYN), dim)),
               rep(dim(observedYY), 3))
  expect_equal(diag(as.matrix(observedNN)), rep(c(3, 6), 10),
               ignore_attr = TRUE)
  expect_equal(diag(as.matrix(observedNY)), rep(0, 20), ignore_attr = TRUE)
  expect_equal(as.matrix(observedNN + observedNY + observedYN + observedYY),
               matrix(getNumGenes(obj), nrow = getNumCells(obj),
                      ncol = getNumCells(obj)),
               ignore_attr = TRUE)

  obj <- estimateDispersionNuBisection(obj, cores = 4, chunkSize = 4,
                                       enforceNuAverageToOne = FALSE)

  c(expectedNN, expectedN) %<-%
    expectedContingencyTablesNN(obj, actOnCells = TRUE, asDspMatrices = FALSE)

  expect_s4_class(expectedNN, "dsyMatrix")
  expect_equal(dim(expectedNN), rep(getNumCells(obj), 2))
  expect_equal(length(expectedN), getNumCells(obj))
  expect_equal(expectedN, rep(c(3, 6), 10),
               ignore_attr = TRUE, tolerance = 1e-3)

  expected <- expectedContingencyTables(obj, actOnCells = TRUE,
                                        asDspMatrices = FALSE)
  c(., expectedNY, expectedYN, expectedYY) %<-% expected

  expect_equal(unlist(lapply(c(expectedYY, expectedNY, expectedYN), dim)),
               rep(dim(expectedNN), 3))
  expect_equal(expectedNY, t(expectedYN))
  expect_equal(as.matrix(expectedNN + expectedNY + expectedYN + expectedYY),
               matrix(getNumGenes(obj), nrow = getNumCells(obj),
                      ncol = getNumCells(obj)),
               ignore_attr = TRUE)

  obj <- calculateCoex(obj, actOnCells = TRUE, optimizeForSpeed = TRUE)

  genesCoexInSync <- getMetadataElement(obj, datasetTags()[["gsync"]])
  cellsCoexInSync <- getMetadataElement(obj, datasetTags()[["csync"]])

  expect_equal(c(genesCoexInSync, cellsCoexInSync), c("FALSE", "TRUE"))

  expect_equal(dim(getCellsCoex(obj)), rep(getNumCells(obj), 2))

  # as all cells are repeated altenating
  expect_true(
    all(abs(getCellsCoex(obj, zeroDiagonal = FALSE)[, seq_len(getNumCells(obj))
                                                        %% 2 == 1] -
              getCellsCoex(obj, zeroDiagonal = FALSE)[, 1]) < 1e-12))
  expect_true(
    all(abs(getCellsCoex(obj, zeroDiagonal = FALSE)[, seq_len(getNumCells(obj))
                                                        %% 2 == 0] -
            getCellsCoex(obj, zeroDiagonal = FALSE)[, 2]) < 1e-12))

  expect_equal(as.matrix(getCellsCoex(obj, zeroDiagonal = FALSE)),
               coexMatrix(observed, expected, getNumGenes(obj),
                          getNumCells(obj)),
               tolerance = 0.001, ignore_attr = TRUE)

  expect_equal(getMetadataDataset(obj)[[1]], datasetTags()[c(5,6,8)],
               ignore_attr = TRUE)
  expect_equal(getMetadataElement(obj, datasetTags()[["cbad"]]), paste0(0))
})


test_that("Coex", {
  raw <- matrix(c(1,0,4,2,11,0,6,7,0,9,10,8,0,0,0,3,0,0,2,0),
                nrow = 10, ncol = 20)
  rownames(raw) = LETTERS[1:10]
  colnames(raw) = letters[1:20]

  obj <- COTAN(raw = raw)
  obj <- clean(obj)

  obj <- estimateDispersionNuBisection(obj, cores = 4, chunkSize = 4,
                                       enforceNuAverageToOne = FALSE)

  obj <- calculateCoex(obj, actOnCells = FALSE, optimizeForSpeed = FALSE)

  expect_equal(dim(getGenesCoex(obj)), rep(getNumGenes(obj), 2))

  S <- as.matrix(calculateS(obj))
  G <- as.matrix(calculateG(obj))

  expect_equal(dim(S), dim(getGenesCoex(obj)))
  expect_equal(dim(G), dim(getGenesCoex(obj)))
  expect_equal(diag(S), rep(0, nrow(S)), ignore_attr = TRUE)
  expect_equal(diag(S), diag(G))
  diag(S) <- 1
  diag(G) <- 1.4
  expect_equal(S[-1, 1] / G[-1, 1], rep(11, 9), tolerance = 1e-3,
               ignore_attr = TRUE)
  expect_true(all(((1.4 * S[-1, -1]) / G[-1, -1]) < 1.2))
  expect_true(all((G[-1, -1] / (1.4 * S[-1, -1])) < 1.2))

  pVS <- calculatePValue(obj, statType = "S")[2:5, 6:9]
  pVG <- calculatePValue(obj, statType = "G",
                         geneSubsetCol = getGenes(obj)[6:9],
                         geneSubsetRow = getGenes(obj)[2:5])

  expect_equal(dim(pVS), dim(pVG))
  expect_true(all((pVS / (pVG * 50)) < 1.1))
  expect_true(all(((pVG * 50) / pVS) < 2.5))

  GDI_S <- calculateGDI(obj, statType = "S")
  GDI_G <- calculateGDI(obj, statType = "G")

  expect_equal(dim(GDI_S), as.integer(c(getNumGenes(obj), 3)))
  expect_equal(dim(GDI_S), dim(GDI_G))
  expect_equal(colnames(GDI_S), c("sum.raw.norm", "GDI", "exp.cells"))
  expect_equal(colnames(GDI_S), colnames(GDI_G))
  expect_equal(GDI_S[[1]], GDI_G[[1]])
  expect_equal(GDI_S[[2]], GDI_G[[2]], tolerance = 0.1)
  expect_equal(GDI_S[[3]], GDI_G[[3]])
  expect_equal(GDI_S[[3]], c(100, rep(50, getNumGenes(obj) - 1)))
})


test_that("Coex vs saved results", {
  utils::data("test.dataset", package = "COTAN")

  obj <- COTAN(raw = test.dataset)
  obj <- initializeMetaDataset(obj, GEO = " ",
                               sequencingMethod = "artificial",
                               sampleCondition = "test")

  obj <- proceedToCoex(obj, cores = 12, saveObj = FALSE)

  genesCoexInSync <- getMetadataElement(obj, datasetTags()[["gsync"]])
  cellsCoexInSync <- getMetadataElement(obj, datasetTags()[["csync"]])

  expect_equal(c(genesCoexInSync, cellsCoexInSync), c("TRUE", "FALSE"))

  obj2 <- automaticCOTANObjectCreation(raw = test.dataset,
                                       GEO = " ",
                                       sequencingMethod = "artificial",
                                       sampleCondition = "test",
                                       cores = 12,
                                       saveObj = FALSE)

  expect_equal(obj2, obj)

  genes.names.test <- readRDS(file.path(getwd(), "genes.names.test.RDS"))

  coex_test <- readRDS(file.path(getwd(), "coex.test.RDS"))

  expect_equal(getGenesCoex(obj, genes = genes.names.test,
                            zeroDiagonal = FALSE), coex_test)

  pval <- calculatePValue(obj, geneSubsetCol = genes.names.test)

  pval_exp <- readRDS(file.path(getwd(), "pval.test.RDS"))
  diag(pval_exp[genes.names.test,]) <- 1
  expect_equal(pval, pval_exp)

  GDI <- calculateGDI(obj)[genes.names.test, ]

  GDI_exp <- readRDS(file.path(getwd(), "GDI.test.RDS"))

  expect_equal(GDI, GDI_exp)
})
