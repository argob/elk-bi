# sql2elk

Ejemplo básico sobre importar datos de una BD a Elasticsearch, manipular los campos con Logstash y hacer visualizaciones en Kibana. Los datos incluidos pertenecen a lugares y establecimientos turísticos de Argentina verificados como accesibles por el Servicio Nacional de Rehabilitación y cubren los tipos de campo fecha, entero, caracteres y punto geográfico.

El stack está compuesto de 4 containers
- [MariaDB](https://github.com/docker-library/mariadb)
- [Elasticsearch](https://github.com/docker-library/elasticsearch)
- [Logstash](https://github.com/docker-library/logstash)
- [Kibana](https://github.com/docker-library/kibana)

## Requerimientos

- docker>=1.10
- docker-compose>=1.7.1

## Configuración

El archivo .env contiene variables de entorno que sirven para configurar el stack en base a necesidades puntuales. Los valores por defecto sirven para levantar el stack entero sin realizar modificaciones

- **INDEX**: el índice de elasticsearch donde se alojarán los datos presentes en MariaDB.
- **MYSQL_HOST**: el hostname del contenedor de MariaDB.
- **MYSQL_USER**: el usuario con permisos (ALL) sobre la base de datos creada al inicio del contenedor.
- **MYSQL_PASSWORD**: la contraseña del usuario nombrado arriba.
- **DELAY**: El tiempo de retardo entre solicitudes de logstash a elasticsearch.
- **MAX_TRIES**: La cantidad máxima de intentos de conexión de logstash a elasticsearch.
- **ES_PROTO**: el protocolo mediante el cual logstash se conectará a elasticsearch.
- **ES_HOST**: el hostname del contenedor de elasticsearch.
- **ES_PORT**: el puerto de elasticsearch al cual logstash realizará la conexión.
- **ELASTICSEARCH_URL**: generalmente la URL compuesta por los 3 anteriores.
- **MODE**: el modo de ejecución de logstash, puede ser "bulk" o "tracker", en caso de no especificarse un modo váido, logstash tomará la decisión del modo en base a la existencia del índice y cantidad de documentos.

## Ejecución

```shell
$ git clone https://github.com/argob/sql2elk
$ docker-compose up
```
*Para evitar el modo interactivo, pasar el parámetro -d"*

1. Una vez levantado el stack, ingresar a la UI de Kibana [localhost:5601](http://localhost:5601).
2. Introducir el nombre del índice (el mismo de la variable $INDEX) en el campo de la sección "Index name or pattern
".
3. Seleccionar el campo con fecha que ordenará los documentos (por ejemplo "creado") y hacer click en "Create".
4. Ir a la pestaña "Saved Objects" y hacer click en "Import".
5. Seleccionar "visualizaciones.json", presente en el repositorio.

### Para ver el dashboard:

Ir a "Dashboards" -> "Open" -> "Lugares"

### Eliminar contenedores

Para eliminar los contenedores
```shell
docker-compose down
```

## Demo 

#### Levantar el stack
[![asciicast](https://asciinema.org/a/3W3XWJdRsYcPk441INPBsYVy8.png)](https://asciinema.org/a/3W3XWJdRsYcPk441INPBsYVy8)

Dejar el stack en ejecución, no es necesario presionar Ctrl + C

#### Configurar índice y visualizaciones
![Kibana](https://www.snr.gob.ar/kibana.gif)
