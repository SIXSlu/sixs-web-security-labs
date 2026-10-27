# --- build stage ---------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

# --- run stage -----------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /opt/harbordock
RUN addgroup -S harbordock && adduser -S harbordock -G harbordock
COPY --from=build /build/target/harbordock-2.4.0.jar app.jar
USER harbordock
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]