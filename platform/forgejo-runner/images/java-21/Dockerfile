FROM eclipse-temurin:21-jdk-jammy

# Node.js 20 LTS (for frontend tooling / IntelliJ plugin builds)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > \
      /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Common build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends git unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Gradle 9.0.0 — installed as system command + pre-cached for wrapper
RUN curl -fsSL https://services.gradle.org/distributions/gradle-9.0.0-bin.zip \
      -o /tmp/gradle.zip && \
    unzip -qd /opt /tmp/gradle.zip && \
    ln -s /opt/gradle-9.0.0/bin/gradle /usr/local/bin/gradle && \
    mkdir -p /root/.gradle/wrapper/dists/gradle-9.0.0-bin && \
    cp /tmp/gradle.zip /root/.gradle/wrapper/dists/gradle-9.0.0-bin/gradle-9.0.0-bin.zip && \
    cd /root/.gradle/wrapper/dists/gradle-9.0.0-bin && \
    unzip -q gradle-9.0.0-bin.zip && \
    rm gradle-9.0.0-bin.zip /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle-9.0.0
ENV MAVEN_HOME=/opt/apache-maven-3.9.9
ENV PATH="${GRADLE_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"

# Maven 3.9.x
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz | \
    tar -xz -C /opt
