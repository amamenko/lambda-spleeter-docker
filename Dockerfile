FROM public.ecr.aws/lambda/python:3.7

ENV SNDFILE_VERSION=1.0.28
ENV MODEL_PATH=${LAMBDA_TASK_ROOT}/pretrained_models

RUN mkdir -m 777 /tmp/NUMBA_CACHE_DIR /tmp/MPLCONFIGDIR
ENV NUMBA_CACHE_DIR=/tmp/NUMBA_CACHE_DIR/
ENV MPLCONFIGDIR=/tmp/MPLCONFIGDIR/
RUN yum -y install tar wget

# Install ffmpeg
ADD https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz /tmp/ffmpeg.tar.xz
RUN cd /tmp &&  \
    tar Jxvf ffmpeg.tar.xz && \
    cp ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/ffmpeg && \
    cp ffmpeg-*-amd64-static/ffprobe /usr/local/bin/ffprobe

# Install libsndfile
RUN mkdir -p "/tmp/sndfile"
RUN yum install -y autoconf autogen automake build-essential libasound2-dev \
  libflac-dev libogg-dev libtool libvorbis-dev libopus-dev pkg-config gcc-c++
WORKDIR "/tmp/sndfile"
RUN curl -L -o "libsndfile-${SNDFILE_VERSION}.tar.gz" "http://www.mega-nerd.com/libsndfile/files/libsndfile-${SNDFILE_VERSION}.tar.gz"
RUN tar xf "libsndfile-${SNDFILE_VERSION}.tar.gz"
WORKDIR "/tmp/sndfile/libsndfile-${SNDFILE_VERSION}"
RUN ./configure --prefix=/opt/
RUN make
RUN make install

WORKDIR /var/task
RUN python -m pip cache purge
RUN pip install --no-cache-dir --upgrade ffmpeg-python boto3 spleeter lambda-warmer-py
RUN pip uninstall -y tensorflow
RUN pip install --no-cache-dir --upgrade tensorflow-cpu 
RUN cd ${LAMBDA_TASK_ROOT} \
    && mkdir -p ./pretrained_models/2stems \
    && wget -O 2stems.tar.gz https://github.com/deezer/spleeter/releases/download/v1.4.0/2stems.tar.gz \
    && tar -xf 2stems.tar.gz -C ./pretrained_models/2stems \
    && rm -r 2stems.tar.gz