### Contenido:
  - [Introducción](#introducción)
  - [Requerimientos](#requerimientos)
  - [Configuración](#configuraci%C3%B3n)
  - [Instalación](#instalaci%C3%B3n)
  - [Demo](#demo)
  - [Desarrollo](#desarrollo)
  - [Contacto](#contacto)

## Introducción

### ¿Qué es ELK?
Es un stack de componentes open source que comprende una base de datos clusterizable del modelo motor de búsqueda y de esquema libre (**E**lasticsearch), un herramienta que recolecta datos de distintas fuentes capaz de parsearlos, mutarlos y grabarlos en Elasticsearch (**L**ogstash) y una interfaz web que da la posibilidad de realizar visualizaciones y búsquedas con la base de datos (**K**ibana). 

Este stack está compuesto de 4 contenedores:
- [MariaDB](https://github.com/docker-library/mariadb)
- [Elasticsearch](https://github.com/docker-library/elasticsearch)
- [Logstash](https://github.com/docker-library/logstash)
- [Kibana](https://github.com/docker-library/kibana)

Los datos parseados por logstash y enviados a elasticsearch provienen de la ejecución de la sentencia "SELECT * FROM lugares_resueltos;" que es una vista que incluye los joins necesarios con tablas referenciales para obtener el valor asociado (por ejemplo: provincia). La tabla principal es "lugares".

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

## Instalación

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

### Dashboard:

Ir a "Dashboards" -> "Open" -> "Lugares"

### Eliminar contenedores

Para eliminar los contenedores
```shell
$ docker-compose down
```

## Demo 

#### Levantar el stack
[![asciicast](https://asciinema.org/a/3W3XWJdRsYcPk441INPBsYVy8.png)](https://asciinema.org/a/3W3XWJdRsYcPk441INPBsYVy8)

Dejar el stack en ejecución, no es necesario presionar Ctrl + C


#### Configurar índice y visualizaciones
![Kibana](https://www.snr.gob.ar/kibana.gif)
![Kibana 2](https://www.snr.gob.ar/kibana2.gif)

## Desarrollo 
#### sql2elk
Ejemplo básico sobre importar datos de una BD a Elasticsearch, manipular los campos con Logstash y hacer visualizaciones en Kibana. Los datos incluidos pertenecen a lugares y establecimientos turísticos de Argentina verificados como accesibles por el Servicio Nacional de Rehabilitación y cubren los tipos de campo fecha, entero, caracteres y punto geográfico.

El orden de arranque de los contenedores es MariaDB - Logstash - Elasticsearch - Kibana

El archivo [turismo.json](https://github.com/argob/elk-bi/blob/master/logstash/conf.d/turismo.json) es la plantilla que contiene las propiedades del índice, tales como el nombre y tipo de campos.

Logstash tiene 2 modos de ejecución:
- bulk: Ejecuta la sentencia "SELECT * FROM lugares_resueltos", en otras palabras trae todas las filas.
- tracker: Ejecuta la sentencia "SELECT * FROM lugares_resueltos WHERE modificado > :sql_last_run" siendo sql_last_run un archivo que contiene la fecha y hora de la última ejecución de logstash. Si alguna fila tiene el campo "modificado" superior a la última ejecución, logstash parseara solamente este registro.

El modo puede ser seteado mediante la variable **MODE**, si la misma está vacía o tiene algún valor distinto a los modos enunciados arriba se definirá el mismo en base a la existencia del índice y/o cantidad de documentos.

Los pasos hasta llegar a la visualización son los siguientes:
1. Se descargan las imágenes del repositorio de Docker (si es que no existen previamente).
2. Se construye la imagen de logstash con los archivos de configuración necesarios: [logstash-bulk.conf](https://github.com/argob/elk-bi/blob/master/logstash/conf.d/logstash-bulk.conf), [logstash-tracker.conf](https://github.com/argob/elk-bi/blob/master/logstash/conf.d/logstash-tracker.conf) y la plantilla [turismo.json](https://github.com/argob/elk-bi/blob/master/logstash/conf.d/turismo.json).
3. Arranca el contenedor de MariaDB con el dump montado en /docker-entrypoint-initdb.d para que pueda ser inicializada.
4. Arranca Elasticsearch.
5. Arranca logstash e intenta conectarse a elasticsearch con el intervalo especificado en la variable **DELAY** hasta que se alcance el valor de **MAX_TRIES**.
6. Se chequea la existencia del índice especificado en **INDEX** y la cantidad de documentos para determinar que archivo de configuración debe ser utilizado.
7. En base a la cantidad de documentos se setea el modo de ejecución de logstash, si hay 0 documentos se ejecutara en modo bulk, de lo contrario en tracker a menos que la variable **MODE** tenga algún modo válido.
8. Logstash ejecuta la consulta, parsea los campos de las filas, en el caso de "ubicacion.coordeanas", se genera un array con los valores de "lat" y "lon".
9. Si es modo bulk, el contenedor se detiene, si es modo tracker sigue en ejecución.

### Utilizar otros datos
Siguiendo el ejemplo, puede crearse un índice con datos propios, para ello se necesita el dump de una base de datos y una plantilla para que mapee los mismos, ademas de alterar la variable **INDEX**. Los nombres de los campos de la plantilla deben coincidir con los de las columnas de la tabla o vista.



## Contacto
Te invitamos a contactarnos en caso de que encuentres algún defecto (bug) o tengas feedback respecto al proyecto.
Para todo lo demás, podés enviarnos tu comentario o consulta a [informatica@snr.gob.ar](mailto:informatica@snr.gob.ar)
