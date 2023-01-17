ARG sndfile_version=1.0.28
ARG model_path=${LAMBDA_TASK_ROOT}/pretrained_models
ARG numba_cache_dir=/tmp/NUMBA_CACHE_DIR/
ARG mplconfigdir=/tmp/MPLCONFIGDIR/

FROM public.ecr.aws/lambda/python:3.7 as builder

ARG sndfile_version
ARG model_path
ARG numba_cache_dir
ARG mplconfigdir

ENV SNDFILE_VERSION=$sndfile_version
ENV MODEL_PATH=$model_path
ENV NUMBA_CACHE_DIR=$numba_cache_dir
ENV MPLCONFIGDIR=$mplconfigdir

RUN mkdir -m 777 /tmp/NUMBA_CACHE_DIR /tmp/MPLCONFIGDIR

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
RUN tar xf "libsndfile-${SNDFILE_VERSION}.tar.gz" && rm -r "libsndfile-${SNDFILE_VERSION}.tar.gz"
WORKDIR "/tmp/sndfile/libsndfile-${SNDFILE_VERSION}"
RUN ./configure --prefix=/opt/
RUN make
RUN make install

WORKDIR /var/task
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade -r requirements.txt
RUN yum -y install tar wget
RUN cd ${LAMBDA_TASK_ROOT} \
    && mkdir -p ./pretrained_models/2stems \
    && wget -O 2stems.tar.gz https://github.com/deezer/spleeter/releases/download/v1.4.0/2stems.tar.gz \
    && tar -xf 2stems.tar.gz -C ./pretrained_models/2stems \
    && rm -r 2stems.tar.gz

FROM public.ecr.aws/lambda/python:3.7

ARG sndfile_version
ARG model_path
ARG numba_cache_dir
ARG mplconfigdir

ENV SNDFILE_VERSION=$sndfile_version
ENV MODEL_PATH=$model_path
ENV NUMBA_CACHE_DIR=$numba_cache_dir
ENV MPLCONFIGDIR=$mplconfigdir

WORKDIR /var/task

COPY --from=builder /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=builder /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=builder /tmp/sndfile /tmp/sndfile
COPY --from=builder /tmp/NUMBA_CACHE_DIR /tmp/NUMBA_CACHE_DIR
COPY --from=builder /tmp/MPLCONFIGDIR /tmp/MPLCONFIGDIR
COPY --from=builder /var/lang/lib/python3.7/site-packages /var/lang/lib/python3.7/site-packages
COPY --from=builder ${LAMBDA_TASK_ROOT}/pretrained_models ${LAMBDA_TASK_ROOT}/pretrained_models

COPY app.py ${LAMBDA_TASK_ROOT}
RUN cd ${LAMBDA_TASK_ROOT} 
CMD [ "app.handler" ]