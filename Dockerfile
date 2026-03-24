# scRNA-Bioc（终镜像）：在 scRNA-Bioc-stage1 上安装富集 / GSVA / SingleR。
#
# 依赖：须已构建并（可选）推送中间镜像 scrna-bioc-stage1:v1。
# 本地未推送时，可先在同一台机器 build stage1 再打相同 tag，再 build 本目录。
#
# 说明：若 Quay 等平台导出的 JSON 日志在 Bioc 安装中途出现新的 build-scheduled/pulling，
#       多为单次 RUN 超时或任务被重试，未必是 R 报错；可将下方安装拆成多段（已拆）并调大构建超时。
# 若日志报 ggtree「check_linewidth not found」或 magick「libMagick++-6.Q16.so.9 找不到」：见下方预装 ggplot2 / 源码 magick 与 ImageMagick -dev。
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

# clusterProfiler → ggtree 需要较新 ggplot2（含 check_linewidth）；P3M 的 magick 二进制常针对较新系统（libMagick++ .so.9），
# 在 Ubuntu 22.04 等环境下会缺库；从源码重装 magick 以链接当前系统的 ImageMagick。
# Debian/Ubuntu 若包名不同（如 noble 的 *t64*），请按发行版调整。
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libmagick++-6.q16-dev \
    libmagickcore-6.q16-dev \
    libmagickwand-6.q16-dev \
 && rm -rf /var/lib/apt/lists/*

# 预装：升级 ggplot2 + 源码编译 magick（再装 Bioc 富集栈）
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  install.packages('ggplot2', repos = 'https://cloud.r-project.org', ask = FALSE, Ncpus = nc); \
  install.packages('magick', repos = 'https://cloud.r-project.org', type = 'source', ask = FALSE, Ncpus = nc)"

# 分步安装：减轻单次 RUN 时长，避免平台超时；失败时缓存可复用已成功的层。
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  BiocManager::install(c('clusterProfiler', 'enrichplot', 'ReactomePA'), \
    ask = FALSE, update = FALSE, Ncpus = nc)"

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
