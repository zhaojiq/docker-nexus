FROM maven:3-jdk-8-alpine AS build
ARG NEXUS_VERSION=3.14.0-04

RUN wget https://github.com/sonatype-nexus-community/nexus-repository-helm/archive/v0.0.5.zip; \
    unzip v0.0.5.zip; \
	mv ./nexus-repository-helm-0.0.5 /nexus-repository-helm; \
	cd /nexus-repository-helm/; sed -i "s/3.14.0-04/${NEXUS_VERSION}/g" pom.xml; \
    mvn clean package;


FROM quay.io/pires/docker-jre:8u171_alpine_3.8.1

LABEL maintainer devops@travelaudience.com

ENV NEXUS_VERSION 3.14.0-04
ENV NEXUS_DOWNLOAD_URL "https://download.sonatype.com/nexus/3"
ENV NEXUS_TARBALL_URL "${NEXUS_DOWNLOAD_URL}/nexus-${NEXUS_VERSION}-unix.tar.gz"
ENV NEXUS_TARBALL_ASC_URL "${NEXUS_DOWNLOAD_URL}/nexus-${NEXUS_VERSION}-unix.tar.gz.asc"
ENV GPG_KEY 0374CF2E8DD1BDFD

ENV SONATYPE_DIR /opt/sonatype
ENV NEXUS_HOME "${SONATYPE_DIR}/nexus"
ENV NEXUS_DATA /nexus-data
ENV NEXUS_CONTEXT ''
ENV SONATYPE_WORK ${SONATYPE_DIR}/sonatype-work

# Install nexus
RUN apk add --no-cache --update bash ca-certificates runit su-exec util-linux
RUN apk add --no-cache -t .build-deps wget gnupg openssl \
  && cd /tmp \
  && echo "===> Installing Nexus ${NEXUS_VERSION}..." \
  && wget -O nexus.tar.gz $NEXUS_TARBALL_URL; \
  wget -O nexus.tar.gz.asc $NEXUS_TARBALL_ASC_URL; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys $GPG_KEY; \
    gpg --batch --verify nexus.tar.gz.asc nexus.tar.gz; \
    rm -r $GNUPGHOME nexus.tar.gz.asc; \
  tar -xf nexus.tar.gz \
  && mkdir -p $SONATYPE_DIR \
  && mv nexus-$NEXUS_VERSION $NEXUS_HOME \
  && cd $NEXUS_HOME \
  && ls -las \
  && adduser -h $NEXUS_DATA -DH -s /sbin/nologin nexus \
  && chown -R nexus:nexus $NEXUS_HOME \
  && rm -rf /tmp/* \
  && apk del --purge .build-deps

# Configure nexus
RUN sed \
    -e '/^nexus-context/ s:$:${NEXUS_CONTEXT}:' \
    -i ${NEXUS_HOME}/etc/nexus-default.properties \
  && sed \
    -e '/^-Xms/d' \
    -e '/^-Xmx/d' \
    -i ${NEXUS_HOME}/bin/nexus.vmoptions

RUN mkdir -p ${NEXUS_DATA}/etc ${NEXUS_DATA}/log ${NEXUS_DATA}/tmp ${SONATYPE_WORK} \
  && ln -s ${NEXUS_DATA} ${SONATYPE_WORK}/nexus3 \
  && chown -R nexus:nexus ${NEXUS_DATA}

# Replace logback configuration
COPY logback.xml ${NEXUS_HOME}/etc/logback/logback.xml
COPY logback-access.xml ${NEXUS_HOME}/etc/logback/logback-access.xml

# Copy runnable script
COPY run /etc/service/nexus/run
RUN  chmod +x /etc/service/nexus/run

VOLUME ${NEXUS_DATA}

EXPOSE 8081

WORKDIR ${NEXUS_HOME}

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m"

RUN mkdir -p ${NEXUS_HOME}/system/org/sonatype/nexus/plugins/nexus-repository-helm/0.0.5/; \
    sed -i 's@nexus-repository-maven</feature>@nexus-repository-maven</feature>\n        <feature version="0.0.5" prerequisite="false" dependency="false">nexus-repository-helm</feature>@g' ${NEXUS_HOME}/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}/nexus-core-feature-${NEXUS_VERSION}-features.xml; \
	sed -i 's@<feature name="nexus-repository-maven"@<feature name="nexus-repository-helm" description="org.sonatype.nexus.plugins:nexus-repository-helm" version="0.0.5">\n        <details>org.sonatype.nexus.plugins:nexus-repository-helm</details>\n        <bundle>mvn:org.sonatype.nexus.plugins/nexus-repository-helm/0.0.5</bundle>\n        <bundle>mvn:org.apache.commons/commons-compress/1.16.1</bundle>\n    </feature>\n    <feature name="nexus-repository-maven"@g' /opt/sonatype/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}/nexus-core-feature-${NEXUS_VERSION}-features.xml;
COPY --from=build /nexus-repository-helm/target/nexus-repository-helm-0.0.5.jar ${NEXUS_HOME}/system/org/sonatype/nexus/plugins/nexus-repository-helm/0.0.5/nexus-repository-helm-0.0.5.jar

CMD ["/sbin/runsvdir", "-P", "/etc/service"]