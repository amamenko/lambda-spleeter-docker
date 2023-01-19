FROM public.ecr.aws/lambda/python:3.7 as builder

ENV SNDFILE_VERSION=1.0.28
ENV MODEL_PATH=${LAMBDA_TASK_ROOT}/pretrained_models
ENV NUMBA_CACHE_DIR=/tmp/NUMBA_CACHE_DIR/
ENV MPLCONFIGDIR=/tmp/MPLCONFIGDIR/
ENV PYTHON_SITE_PACKAGES=/var/lang/lib/python3.7/site-packages

RUN mkdir -m 777 /tmp/NUMBA_CACHE_DIR /tmp/MPLCONFIGDIR /tmp/sndfile

# Install ffmpeg
ADD https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz /tmp/ffmpeg.tar.xz
RUN cd /tmp && \
    tar Jxvf ffmpeg.tar.xz && \
    cp ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/ffmpeg && \
    cp ffmpeg-*-amd64-static/ffprobe /usr/local/bin/ffprobe

# Install libsndfile
RUN yum install -y autoconf autogen automake build-essential libasound2-dev \
  libflac-dev libogg-dev libtool libvorbis-dev libopus-dev pkg-config gcc-c++
WORKDIR "/tmp/sndfile"
RUN curl -L -o "libsndfile-${SNDFILE_VERSION}.tar.gz" "http://www.mega-nerd.com/libsndfile/files/libsndfile-${SNDFILE_VERSION}.tar.gz" && \
    tar xf "libsndfile-${SNDFILE_VERSION}.tar.gz" && \
    rm -r "libsndfile-${SNDFILE_VERSION}.tar.gz"
WORKDIR "/tmp/sndfile/libsndfile-${SNDFILE_VERSION}"
RUN ./configure --prefix=/opt/ && make && make install

WORKDIR /var/task
RUN cd ${LAMBDA_TASK_ROOT} && \
    mkdir -p ./pretrained_models/2stems && \
    yum -y install tar wget && \
    wget -O 2stems.tar.gz https://github.com/deezer/spleeter/releases/download/v1.4.0/2stems.tar.gz && \
    tar -xf 2stems.tar.gz -C ./pretrained_models/2stems && \
    rm -r 2stems.tar.gz

FROM public.ecr.aws/lambda/python:3.7

ENV SNDFILE_VERSION=1.0.28
ENV MODEL_PATH=${LAMBDA_TASK_ROOT}/pretrained_models
ENV NUMBA_CACHE_DIR=/tmp/NUMBA_CACHE_DIR/
ENV MPLCONFIGDIR=/tmp/MPLCONFIGDIR/

WORKDIR /var/task

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade -r requirements.txt && \
    find /var/lang/lib/python3.7/site-packages -name "*.dist-info"  -exec rm -rf {} \; | true && \
    find /var/lang/lib/python3.7/site-packages -name "*.egg-info"  -exec rm -rf {} \; | true && \
    find /var/lang/lib/python3.7/site-packages -name "*.pth"  -exec rm -rf {} \; | true && \
    find /var/lang/lib/python3.7/site-packages -name "__pycache__"  -exec rm -rf {} \; | true && \
    rm -r requirements.txt
COPY --from=builder /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=builder /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=builder /tmp/sndfile /tmp/sndfile
COPY --from=builder /tmp/NUMBA_CACHE_DIR /tmp/NUMBA_CACHE_DIR
COPY --from=builder /tmp/MPLCONFIGDIR /tmp/MPLCONFIGDIR
COPY --from=builder /opt/lib /opt/lib
COPY --from=builder ${LAMBDA_TASK_ROOT}/pretrained_models ${LAMBDA_TASK_ROOT}/pretrained_models

COPY app.py ${LAMBDA_TASK_ROOT}
RUN cd ${LAMBDA_TASK_ROOT} 
CMD [ "app.handler" ]