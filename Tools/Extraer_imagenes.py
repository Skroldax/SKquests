import json
import os
import zipfile

def extraer_y_renombrar():
    # Definimos la ruta de tu carpeta de trabajo
    ruta_carpeta = r"C:\Users\skrol\OneDrive\Escritorio\Addon klo maldito\Tools"

    docx_input = os.path.join(ruta_carpeta, "Horde_1_60.docx")
    json_input = os.path.join(ruta_carpeta, "indice_imagenes.json")
    
    # Carpeta de salida exacta donde el AddOn leerá las imágenes
    carpeta_imagenes_out = os.path.join(ruta_carpeta, "Images")

    # Validar que los archivos necesarios estén ahí
    if not os.path.exists(docx_input) or not os.path.exists(json_input):
        print(f"Error: Asegúrate de tener 'Alliance_1_60.docx' e 'indice_imagenes.json' en:\n-> {ruta_carpeta}")
        return

    print("Leyendo índice de imágenes...")
    with open(json_input, 'r', encoding='utf-8') as f:
        indice_json = json.load(f)

    # Crear la carpeta final 'Images' si no existe
    if not os.path.exists(carpeta_imagenes_out):
        os.makedirs(carpeta_imagenes_out)

    print("Abriendo documento Word de la Alianza...")
    # Un archivo .docx es técnicamente un archivo ZIP oculto. Podemos abrirlo directamente.
    try:
        with zipfile.ZipFile(docx_input, 'r') as docx_zip:
            print("Extrayendo y renombrando imágenes localmente...")
            
            imagenes_creadas = 0
            for elemento in indice_json:
                ruta_original = elemento.get("ruta_original_docx")      # ej: "word/media/image1.jpeg"
                nombre_final = elemento.get("nombre_archivo")          # ej: "imagen_001.jpeg"
                
                if ruta_original and nombre_final:
                    try:
                        # Leer los bytes de la imagen del interior del Word
                        datos_imagen = docx_zip.read(ruta_original)
                        
                        # Ruta final donde guardaremos la imagen limpia
                        ruta_destino_final = os.path.join(carpeta_imagenes_out, nombre_final)
                        
                        # Guardar el archivo en el disco
                        with open(ruta_destino_final, 'wb') as f_out:
                            f_out.write(datos_imagen)
                        
                        imagenes_creadas += 1
                    except KeyError:
                        # Si una imagen del JSON no se encuentra en este Word específico, se la salta sin romper el script
                        continue

            print(f"\n¡Éxito total! Se han extraído y renombrado {imagenes_creadas} imágenes correctamente.")
            print(f"Las encontrarás listas en la carpeta:\n-> {carpeta_imagenes_out}")

    except Exception as e:
        print(f"Ocurrió un error al procesar el archivo Word: {e}")

if __name__ == "__main__":
    extraer_y_renombrar()