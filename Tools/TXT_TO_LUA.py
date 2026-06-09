import json
import os
import re

def generar_lua():
    # Ruta absoluta de tu carpeta de trabajo
    ruta_carpeta = r"C:\Users\skrol\OneDrive\Escritorio\Addon klo maldito\Tools"

    txt_input = os.path.join(ruta_carpeta, "texto_completo.txt")
    json_input = os.path.join(ruta_carpeta, "indice_imagenes.json")
    
    # Archivos de salida separados por facción
    lua_alliance_out = os.path.join(ruta_carpeta, "Alliance_1_60.lua")
    lua_horde_out = os.path.join(ruta_carpeta, "Horde_1_60.lua")

    if not os.path.exists(txt_input) or not os.path.exists(json_input):
        print(f"Error: No se encontraron los archivos en: {ruta_carpeta}")
        return

    print("Procesando secciones, títulos de zona y limpiando textos innecesarios...")

    # 1. Cargar el JSON de imágenes
    with open(json_input, 'r', encoding='utf-8') as f:
        contenido_json = json.load(f)

    datos_imagenes = {}
    if isinstance(contenido_json, dict):
        datos_imagenes = contenido_json
    elif isinstance(contenido_json, list):
        for elemento in contenido_json:
            if isinstance(elemento, dict):
                id_key = next((k for k in ['indice', 'id', 'paso', 'step'] if k in elemento), None)
                img_key = next((k for k in ['nombre_archivo', 'imagen', 'image', 'ruta'] if k in elemento), None)
                if id_key and img_key:
                    datos_imagenes[str(elemento[id_key])] = str(elemento[img_key])

    # 2. Leer el archivo de texto completo
    with open(txt_input, 'r', encoding='utf-8') as f:
        contenido_txt = f.read()

    # Separar Alianza de Horda de forma segura (la bandera (?i) va al inicio del patrón)
    partes_faccion = re.split(r'(?i)\n(?:Horde|Horda)', contenido_txt, maxsplit=1)
    
    texto_alianza = partes_faccion[0]
    texto_horda = partes_faccion[1] if len(partes_faccion) > 1 else ""

    # Función interna para procesar los bloques '#' de cada facción
    def procesar_faccion(texto_completo_faccion):
        # Busca el '#' seguido del número y todo lo que viene debajo hasta el siguiente '#' o fin de texto
        bloques_gato = re.findall(r'#(\d+)\s*\n(.*?)(?=\n#\d+|$)', texto_completo_faccion, re.DOTALL)
        
        pasos_limpios = []
        for id_imagen, cuerpo_texto in bloques_gato:
            texto_bloque = cuerpo_texto.strip()
            if not texto_bloque:
                continue

            lineas = texto_bloque.split('\n')
            lineas_titulo = []
            lineas_instrucciones = []

            # Clasificar líneas entre lo que es Título (texto descriptivo) e Instrucciones (lista de misiones)
            for linea in lineas:
                linea_limpia = linea.strip()
                if not linea_limpia:
                    continue

                # REQUISITO NUEVO: Remover la frase de elegir clase de cualquier parte
                if "remember to choose your class" in linea_limpia.lower():
                    continue

                # Si contiene "(log)", limpiamos la marca y la tratamos como título
                if "(log)" in linea_limpia.lower():
                    linea_sin_log = re.split(r'(?i)\(log\)', linea_limpia)[0].strip()
                    # Quitamos posibles números iniciales de lista sobrantes (ej: "4. " o "04) ")
                    linea_sin_log = re.sub(r'^\d+[\.\-\)]\s*', '', linea_sin_log).strip()
                    if linea_sin_log:
                        lineas_titulo.append(linea_sin_log)
                    continue

                # Si la línea empieza con numeración de pasos (ej: "01)", "1.", "1-") es una instrucción
                if re.match(r'^\d+[\.\-\)]', linea_limpia):
                    lineas_instrucciones.append(linea)
                else:
                    # Si es texto plano (como "Human" o "1-13 Elwynn Forest:") que va ANTES de los pasos, es el título
                    if not lineas_instrucciones:
                        # Limpiamos los dos puntos finales si existen
                        linea_formateada = linea_limpia.rstrip(':').strip()
                        if linea_formateada:
                            lineas_titulo.append(linea_formateada)
                    else:
                        # Si aparece texto plano después de que ya empezaron los pasos, pertenece a las instrucciones
                        lineas_instrucciones.append(linea)

            # Unir los títulos encontrados (ej: "Human - 1-13 Elwynn Forest - 1-6 Northshire")
            titulo_final = " - ".join(lineas_titulo).strip()

            pasos_limpios.append({
                "imagen_id": id_imagen.strip(),
                "title": titulo_final,
                "text": "\n".join(lineas_instrucciones).strip()
            })
        return pasos_limpios

    # Procesar ambas facciones por separado
    pasos_alliance = procesar_faccion(texto_alianza)
    pasos_horde = procesar_faccion(texto_horda)

    # Función para estructurar y exportar la tabla final de Lua
    def guardar_archivo_lua(ruta_salida, nombre_tabla, lista_pasos):
        lineas_lua = []
        lineas_lua.append(f"-- Archivo generado automáticamente para SKuests")
        lineas_lua.append(f"{nombre_tabla} = {{")

        for indice, paso in enumerate(lista_pasos, start=1):
            ruta_imagen = datos_imagenes.get(paso["imagen_id"], "")

            lineas_lua.append(f"    [{indice}] = {{")
            lineas_lua.append(f"        step = {indice},")
            lineas_lua.append(f'        title = "{paso["title"]}",')
            lineas_lua.append(f"        text = [[\n{paso['text']}\n        ]],")
            lineas_lua.append(f'        image = "{ruta_imagen}",')
            lineas_lua.append("    },")

        lineas_lua.append("}")

        with open(ruta_salida, 'w', encoding='utf-8') as f:
            f.write("\n".join(lineas_lua))

    # 3. Exportar los dos archivos independientes
    if pasos_alliance:
        guardar_archivo_lua(lua_alliance_out, "Alliance_1_60", pasos_alliance)
        print(f"-> Archivo generado: 'Alliance_1_60.lua' con {len(pasos_alliance)} pasos.")
        
    if pasos_horde:
        guardar_archivo_lua(lua_horde_out, "Horde_1_60", pasos_horde)
        print(f"-> Archivo generado: 'Horde_1_60.lua' con {len(pasos_horde)} pasos.")
    else:
        print("Nota: No se detectó ninguna sección de la Horda o el texto después de 'Horde' estaba vacío.")

if __name__ == "__main__":
    generar_lua()