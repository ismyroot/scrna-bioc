# scRNA-Bioc：在 scRNA-base 之上叠加 Bioconductor 富集 / GSVA / SingleR 等扩展（对应方案中的 singlecell-bioc，约 16 个工具）。
#
# 基础层：quay.io/1733295510/scrna-base:v1（已含 Seurat + Quarto + TeX + 常用 CRAN 补包）
# 本层：CRAN 包用 remotes::install_version 与 docker_version.txt 对齐；Bioconductor 用 BiocManager::install（R 4.4.x 默认 Bioc 3.19，与 org.*.db 3.19.x 线一致）。
#
# 构建示例：
#   cd /home/ubuntu/zhaoyiran/TOOL-Dockerfile/singlecell/scRNA-Bioc
#   docker build -t scRNA-Bioc:latest .
#   docker tag scRNA-Bioc:latest quay.io/1733295510/scrna-bioc:v1

FROM quay.io/1733295510/scrna-base:v1

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-Bioc"
LABEL org.opencontainers.image.description="Single-cell Bioc layer: clusterProfiler, GSVA, SingleR, org.*.db, etc. (singlecell-bioc plan)."

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# CRAN 依赖（与仓库根目录 docker_version.txt 一致）
RUN R -e "remotes::install_version('circlize', '0.4.17', repos='https://cloud.r-project.org', upgrade='never')" && \
    R -e "remotes::install_version('ggrepel', '0.9.6', repos='https://cloud.r-project.org', upgrade='never')" && \
    R -e "remotes::install_version('ggridges', '0.5.7', repos='https://cloud.r-project.org', upgrade='never')"

# Bioconductor / Annotation（R 4.4.x 默认 Bioc 3.19，与 org.*.db 3.19.x 一致；顺序：注释库 → 统计/表达容器 → 富集与 GSVA → SingleR）
RUN R -e "BiocManager::install(c(\
      'AnnotationDbi', \
      'org.Hs.eg.db', 'org.Mm.eg.db', 'org.Rn.eg.db', \
      'biomaRt', \
      'limma', \
      'GSEABase', 'SummarizedExperiment', 'BiocParallel', \
      'clusterProfiler', 'enrichplot', 'ReactomePA', \
      'GSVA', \
      'SingleR', 'celldex'\
    ), ask = FALSE, update = FALSE)"

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
