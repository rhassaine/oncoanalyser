FROM continuumio/miniconda3:23.5.2-0-alpine as build

RUN \
    conda install conda-libmamba-solver

RUN \
    echo -e > ~/.condarc '\
solver: libmamba\n\
channels:\n\
    - conda-forge\n\
    - bioconda\n\
    - defaults'

RUN \
  conda create -y -p /env/ \
    'openjdk >=8'

# NOTE(SW): TEAL JAR built from hartwigmedical/hmftools at commit 563f6e0
COPY teal.jar /tmp/
RUN \
  mkdir -p /opt/teal/ && \
  mv /tmp/teal.jar /opt/teal/teal.jar

RUN \
    conda clean -yaf

# Move Conda environment into standard BioContainers base image
FROM quay.io/bioconda/base-glibc-busybox-bash:2.1.0

COPY --from=build /env/ /env/
COPY --from=build /opt/teal/ /opt/teal/

ENV PATH="/env/bin:${PATH}"
ENV LD_LIBRARY_PATH="/env/lib/:${LD_LIBRARY_PATH}"
