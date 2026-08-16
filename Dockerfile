FROM ghcr.io/cirruslabs/flutter:3.38.5 AS build

WORKDIR /app

RUN flutter config --enable-web

COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get

COPY . .

RUN flutter build web --release


FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
