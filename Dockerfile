# scRNA-Bioc（终镜像）：在 scRNA-Bioc-stage1 上安装富集 / GSVA / SingleR。
#
# 依赖：须已构建并（可选）推送中间镜像 scrna-bioc-stage1:v1。
# 本地未推送时，可先在同一台机器 build stage1 再打相同 tag，再 build 本目录。
#
# 说明：若 Quay 等平台导出的 JSON 日志在 Bioc 安装中途出现新的 build-scheduled/pulling，
#       多为单次 RUN 超时或任务被重试，未必是 R 报错；可将下方安装拆成多段（已拆）并调大构建超时。
# 若日志报 ggtree「check_linewidth not found」：常见是装了 ggplot2 4.x（CRAN 当前默认），4.x 已移除该内部符号，而 Bioc 3.20 的 ggtree 3.14 仍依赖它。
#       对策：用 CRAN Archive 固定 ggplot2 3.5.2；repos 的 CRAN 指 cloud；富集栈 BiocManager::install 用 Ncpus=1，减轻并行与 ggtree Makefile（如 ggtree.ts）冲突。
#       另：P3M 若装上 ggplot2 3.3 等过旧版也会缺 check_linewidth，同样用固定 3.5.2 + cloud 规避。magick 缺库：见 ImageMagick -dev。
#
# 构建示例：
#   docker build --build-arg R_INSTALL_NCPUS=8 -t quay.io/1733295510/scrna-bioc:v1 .

ARG STAGE1_IMAGE=quay.io/1733295510/scrna-bioc-stage1:v1
FROM ${STAGE1_IMAGE}

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-Bioc"
LABEL org.opencontainers.image.description="Full singlecell-bioc: stage1 + clusterProfiler, GSVA, SingleR, celldex, etc."

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG R_INSTALL_NCPUS=4
ENV R_INSTALL_NCPUS=${R_INSTALL_NCPUS}

# clusterProfiler → ggtree 需要 ggplot2 3.4–3.5（含 check_linewidth），勿用 4.x；P3M 的 magick 二进制常针对较新系统（libMagick++ .so.9），
# 在 Ubuntu 22.04 等环境下会缺库；从源码重装 magick 以链接当前系统的 ImageMagick。
# Debian/Ubuntu 若包名不同（如 noble 的 *t64*），请按发行版调整。
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libmagick++-6.q16-dev \
    libmagickcore-6.q16-dev \
    libmagickwand-6.q16-dev \
 && rm -rf /var/lib/apt/lists/*

# 预装：ggplot2 固定 3.5.2（与 ggtree 3.14 兼容；勿装 CRAN 当前 4.x）+ 源码 magick
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc, repos = c(CRAN = 'https://cloud.r-project.org')); \
  install.packages('https://cran.r-project.org/src/contrib/Archive/ggplot2/ggplot2_3.5.2.tar.gz', repos = NULL, type = 'source', dependencies = TRUE, ask = FALSE, Ncpus = nc); \
  stopifnot(packageVersion('ggplot2') == '3.5.2'); \
  install.packages('magick', repos = 'https://cloud.r-project.org', type = 'source', ask = FALSE, Ncpus = nc)"

# 分步安装：减轻单次 RUN 时长，避免平台超时；失败时缓存可复用已成功的层。
# 本段：CRAN=cloud → 再钉一次 ggplot2 3.5.2（防止 Bioc 依赖解析拉到 4.x 或过旧二进制）→ 串行装富集栈。
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  repos <- BiocManager::repositories(); \
  repos['CRAN'] <- 'https://cloud.r-project.org'; \
  options(repos = repos); \
  install.packages('https://cran.r-project.org/src/contrib/Archive/ggplot2/ggplot2_3.5.2.tar.gz', repos = NULL, type = 'source', dependencies = TRUE, ask = FALSE, Ncpus = nc); \
  stopifnot(packageVersion('ggplot2') == '3.5.2'); \
  BiocManager::install(c('clusterProfiler', 'enrichplot', 'ReactomePA'), \
    ask = FALSE, update = FALSE, Ncpus = 1L); \
  stopifnot(packageVersion('ggplot2') == '3.5.2'); \
  stopifnot(requireNamespace('clusterProfiler', quietly = TRUE), \
    requireNamespace('enrichplot', quietly = TRUE), \
    requireNamespace('ReactomePA', quietly = TRUE))"

RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  BiocManager::install('GSVA', ask = FALSE, update = FALSE, Ncpus = nc)"

RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  BiocManager::install(c('SingleR', 'celldex'), ask = FALSE, update = FALSE, Ncpus = nc)"

RUN R -e "\
  suppressPackageStartupMessages({\
    library(AnnotationDbi);\
    library(clusterProfiler);\
    library(enrichplot);\
    library(ReactomePA);\
    library(GSVA);\
    library(GSEABase);\
    library(SingleR);\
    library(celldex);\
  });\
  cat('scRNA-Bioc OK: clusterProfiler', as.character(packageVersion('clusterProfiler')), \
      ' GSVA', as.character(packageVersion('GSVA')), \
      ' SingleR', as.character(packageVersion('SingleR')), '\n')\
"

WORKDIR /work
