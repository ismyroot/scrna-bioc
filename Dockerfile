# scRNA-Bioc（终镜像）：在 scRNA-Bioc-stage1 上安装富集 / GSVA / SingleR。
#
# 依赖：须已构建并（可选）推送中间镜像 scrna-bioc-stage1:v1。
# 本地未推送时，可先在同一台机器 build stage1 再打相同 tag，再 build 本目录。
#
# 构建示例：
#   docker build -t quay.io/1733295510/scrna-bioc:v1 .

ARG STAGE1_IMAGE=quay.io/1733295510/scrna-bioc-stage1:v1
FROM ${STAGE1_IMAGE}

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-Bioc"
LABEL org.opencontainers.image.description="Full singlecell-bioc: stage1 + clusterProfiler, GSVA, SingleR, celldex, etc."

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN R -e "BiocManager::install(c(\
      'clusterProfiler', 'enrichplot', 'ReactomePA', \
      'GSVA', \
      'SingleR', 'celldex'\
    ), ask = FALSE, update = FALSE)" && \
    R -e "\
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
