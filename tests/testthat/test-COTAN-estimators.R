
test_that("Linear estimates", {
  raw <- matrix(c(1,0,4,2,11,0,6,7,0,9,10,8,0,0,0,3,0,0,2,0),
                nrow = 10, ncol = 20)
  rownames(raw) = LETTERS[1:10]
  colnames(raw) = letters[1:20]

  obj <- COTAN(raw = raw)

  obj <- estimateLambdaLinear(obj)

  expect_equal(getLambda(obj), rowMeans(getRawData(obj), dims = 1))
  expect_equal(getMetadataDataset(obj)[[1]], datasetTags()[5:6],
               ignore_attr = TRUE)
  expect_equal(getMetadataDataset(obj)[[2]], c("FALSE", "FALSE"))

  obj <- estimateNuLinear(obj)

  expect_equal(getNu(obj), colMeans(getRawData(obj), dims = 1)
                             / mean(colMeans(getRawData(obj), dims = 1)))
})


test_that("Bisection estimates", {
  raw <- matrix(c(1,0,4,2,11,0,6,7,0,9,10,8,0,0,0,3,0,0,2,0),
                nrow = 10, ncol = 20)
  rownames(raw) = LETTERS[1:10]
  colnames(raw) = letters[1:20]

  obj <- COTAN(raw = raw)
  obj <- clean(obj)

  obj <- estimateDispersionBisection(obj, cores = 3, chunkSize = 2)

  expect_equal(length(getDispersion(obj)), getNumGenes(obj))
  expect_equal(getDispersion(obj)[1], -Inf, ignore_attr = TRUE)

  expect_equal(rowSums(getZeroOneProj(obj) + funProbZero(getDispersion(obj),
                                                         calculateMu(obj))),
              rep(getNumCells(obj), getNumGenes(obj)),
              tolerance = 0.001, ignore_attr = TRUE)

  obj <- estimateNuBisection(obj, cores = 6, chunkSize = 3)

  expect_equal(length(getNu(obj)), getNumCells(obj))

  expect_equal(colSums(getZeroOneProj(obj) + funProbZero(getDispersion(obj),
                                                         calculateMu(obj))),
               rep(getNumGenes(obj), getNumCells(obj)),
               tolerance = 0.001, ignore_attr = TRUE)

  obj <- estimateDispersionNuBisection(obj, enforceNuAverageToOne = TRUE)

  expect_equal(length(getDispersion(obj)), getNumGenes(obj))
  expect_equal(getDispersion(obj)[1], -Inf, ignore_attr = TRUE)
  expect_equal(length(getNu(obj)), getNumCells(obj))
  expect_equal(mean(getNu(obj)), 1.0)

  expect_equal(rowSums(getZeroOneProj(obj) + funProbZero(getDispersion(obj),
                                                         calculateMu(obj))),
               rep(getNumCells(obj), getNumGenes(obj)),
               tolerance = 0.001, ignore_attr = TRUE)

  expect_equal(colSums(getZeroOneProj(obj) + funProbZero(getDispersion(obj),
                                                         calculateMu(obj))),
               rep(getNumGenes(obj), getNumCells(obj)),
               tolerance = 0.001, ignore_attr = TRUE)

  expect_error(estimateDispersionNuNlminb(obj))
})
