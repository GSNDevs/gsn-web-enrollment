# Portal de Identidad (Prueba Match) - Flujo de Ingreso

Esta aplicación móvil (Flutter) está diseñada para automatizar y agilizar el proceso de verificación de choferes, extrayendo datos y validando documentos biométricos en la entrada (Flujo de Ingreso). El proceso se conecta a la base de datos **Supabase**, utilizando servicios OCR y de comparación facial (Face Match).

A continuación se detalla el flujo de validación que experimenta el usuario paso a paso:

## Flujo de Pantallas en Orden

1. **Ingreso y Validación Inicial**
   - El choque o usuario accede con un registro o **Rut/Código de autenticación**.
   - El sistema valida este código para vincular la información (en `auth_screen.dart` / Login).

2. **Selección de Tipo de Vehículo (`VehicleSelectionView`)**
   - El usuario selecciona qué tipo de vehículo conduce:
     - **Vehículo Menor**
     - **Vehículo Mayor**
   - Esta elección afectará los pasos requeridos más adelante en el flujo.

3. **Verificación Biométrica y Cédula (`FaceMatchScreen`)**
   - Se le solicita al usuario usar la cámara personalizada del dispositivo para dos fotografías, ambas con una calidad máxima y guías visuales en pantalla:
     - **Selfie:** Se enmarca el rostro dentro de un *óvalo vertical*.
     - **Carnet de Identidad:** Se enmarca el documento dentro de un *rectángulo horizontal*.
   - El sistema ejecuta un proceso backend de OCR (Extracción de texto del carnet) y Validación de Vida/Match Facial (comparando el carnet con la selfie). Las imágenes se comprimen de forma inteligente usando `ImageHelper` antes de su procesamiento y subida.

4. **Confirmación de Datos Personales (`ConfirmationView`)**
   - Una vez obtenidos los datos del paso anterior (OCR del Carnet), se muestra un formulario para validar que estén correctos.
   - Se revisan campos clave como Nombres, Edad, y Rut. Las fechas indican obligatoriamente el formato *dd-mm-YYYY*.
   - Una vez confirmados, se envían y registran en la base de datos de Supabase.

5. **Escaneo de Licencia de Conducir (`IDScanView` / `FaceMatchScreen` modo ScanOnly)**
   - De manera similar al carnet, se solicita escanear la licencia de conducir vigente.
   - Utiliza la misma modalidad de encuadrar el documento en un rectángulo y extrae sus datos al instante.

6. **Confirmación de Datos Licencia (`LicenseConfirmationView`)**
   - Se muestra la información detectada de la licencia y el usuario verifica que el tipo de licencia (ejemplo: Clase A, B), fecha de emisión y de vencimiento coincidan.

7. **Escaneo de Documento de Transporte - BL/Guía (`TakePhotoView`)**
   - El usuario debe capturar una fotografía del *Bill of Lading* o Guía de Despacho.
   - **Excepción inteligente:** Si en el **Paso 2** el usuario seleccionó `"Vehículo Menor"`, la pantalla mostrará el botón **"NO APLICA AL BL"**. Al presionarlo, le permitirá omitir fotografiar este documento y avanzar más rápido.

8. **Datos del Vehículo (`VehicleDataView`)**
   - El usuario tipea manualmente:
     - La **Patente** del transporte.
     - El número de **Container**.

9. **Consultas Finales y Carga Peligrosa**
   - Dependiendo del flujo específico, la aplicación pregunta si está transportando *Carga Peligrosa*, guardando el booleano en el sistema.

10. **Agendamiento (Opcional según flujo)**
    - El chofer visualiza la disponibilidad de cupos y selecciona un bloque de horario para agendar oficialmente la entrega/ingreso.

11. **Finalización del Registro**
    - Todo el flujo termina sincronizando firmemente con Supabase:
      - Los archivos estáticos (`Selfie`, `Carnet`, `Licencia`, `Foto BL`) se alojan en sus *Buckets* respectivos en Storage.
      - Todos los datos procesados, la biometría y los punteros de imagen se guardan en las tablas `choferes`, `licencias_conducir` y `registro_choferes`.

---

## Características Técnicas Críticas

- **CustomCameraView**: Utiliza `camera: ^0.11.2`. Evita el estiramiento y ajusta nativamente los encuadres para asegurar la alta calidad del material proporcionado al OCR, bloqueando la vista a portrait horizontal, asegurando consistencia.
- **Compresión Integrada**: Usa la librería `image_helper.dart` (para `flutter_image_compress`), donde el balance perfecto disminuye el peso en red preservando la legibilidad.
- **Supabase Realtime**: Integración de consultas y subidas de forma asíncrona hacia bases y storages en Supabase.
