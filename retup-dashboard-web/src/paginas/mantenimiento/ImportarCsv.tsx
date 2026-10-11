// ═══════════════════════════════════════════════════════════════════
// MANTENIMIENTO · ALTA MASIVA POR CSV
// 1) Lee el CSV en el navegador (Papa Parse: separador , o ; y acentos)
// 2) El backend lo revisa en SIMULACIÓN y se muestra la vista previa
// 3) Sin errores -> importar. Al final se descarga el archivo con las
//    contraseñas temporales (no se muestran en pantalla).
// ═══════════════════════════════════════════════════════════════════
import { useEffect, useRef, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import Papa from 'papaparse';
import { apiFetch } from '../../api/cliente';
import './FormularioAlta.css';
import './ImportarCsv.css';

// ───────────── Columnas del archivo ─────────────
const COLUMNAS = [
  'nombre',
  'apellido1',
  'apellido2',
  'email',
  'departamento',
  'equipo',
  'cargo',
  'fecha_ingreso',
] as const;
type Columna = (typeof COLUMNAS)[number];
type FilaCsv = Record<Columna, string>;

const OBLIGATORIAS: Columna[] = ['nombre', 'apellido1', 'email'];
const MAX_FILAS = 300;

/** Títulos de columna que también se aceptan (ya en minúsculas, sin tildes, con _ en vez de espacios) */
const ALIAS: Record<string, Columna> = {
  nombre: 'nombre',
  nombres: 'nombre',
  apellido1: 'apellido1',
  apellido_1: 'apellido1',
  primer_apellido: 'apellido1',
  apellido2: 'apellido2',
  apellido_2: 'apellido2',
  segundo_apellido: 'apellido2',
  email: 'email',
  e_mail: 'email',
  mail: 'email',
  correo: 'email',
  correo_electronico: 'email',
  departamento: 'departamento',
  equipo: 'equipo',
  cargo: 'cargo',
  puesto: 'cargo',
  fecha_ingreso: 'fecha_ingreso',
  fecha_de_ingreso: 'fecha_ingreso',
  ingreso: 'fecha_ingreso',
};

// ───────────── Respuestas del backend ─────────────
interface Resumen {
  total: number;
  validas: number;
  con_errores: number;
  departamentos_nuevos: string[];
  equipos_nuevos: string[];
  creadas?: number;
  fallidas?: number;
}

interface FilaRevision {
  fila: number;
  nombre: string;
  email: string;
  departamento: string | null;
  departamento_nuevo: boolean;
  equipo: string | null;
  equipo_nuevo: boolean;
  errores: string[];
}

interface RespuestaRevision {
  success: boolean;
  resumen: Resumen;
  filas: FilaRevision[];
}

interface FilaImportada {
  fila: number;
  nombre: string;
  email: string;
  estado: 'creada' | 'error';
  password_temporal?: string;
  error?: string;
}

interface RespuestaImportacion {
  success: boolean;
  resumen: Resumen;
  filas: FilaImportada[];
}

// ───────────── Ayudantes ─────────────
/** "Fecha de Ingreso" -> "fecha_de_ingreso" (sin tildes ni mayúsculas) */
function normalizarTitulo(titulo: string): string {
  return titulo
    .replace(/^\uFEFF/, '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[\s-]+/g, '_');
}

/** Lee el archivo como texto. Si no es UTF-8 (CSV "ANSI" de Excel), lo relee como Windows-1252 */
async function leerTexto(archivo: File): Promise<string> {
  const utf8 = await archivo.text();
  if (!utf8.includes('\uFFFD')) return utf8;
  return new TextDecoder('windows-1252').decode(await archivo.arrayBuffer());
}

/** Convierte el texto del CSV en filas con nuestras 8 columnas, o devuelve el error */
function interpretarCsv(texto: string): { filas: FilaCsv[] } | { error: string } {
  const resultado = Papa.parse<Record<string, string>>(texto, {
    header: true,
    skipEmptyLines: 'greedy',
    transformHeader: normalizarTitulo,
  });

  const titulos = resultado.meta.fields ?? [];
  if (titulos.length === 0) return { error: 'El archivo está vacío.' };

  // Qué título del archivo corresponde a cada columna nuestra
  const columnaDeTitulo = new Map<string, Columna>();
  for (const titulo of titulos) {
    const columna = ALIAS[titulo];
    if (columna) columnaDeTitulo.set(titulo, columna);
  }

  const presentes = new Set(columnaDeTitulo.values());
  const faltan = OBLIGATORIAS.filter((c) => !presentes.has(c));
  if (faltan.length > 0) {
    return {
      error: `Faltan columnas obligatorias: ${faltan.join(', ')}. La primera fila debe tener los títulos de las columnas (descarga la plantilla para ver el formato).`,
    };
  }
  if (resultado.data.length === 0) return { error: 'El archivo no tiene ninguna persona.' };
  if (resultado.data.length > MAX_FILAS) {
    return {
      error: `El archivo tiene ${resultado.data.length} personas. El máximo es ${MAX_FILAS}: divídelo en partes.`,
    };
  }

  const filas = resultado.data.map((original) => {
    const fila = Object.fromEntries(COLUMNAS.map((c) => [c, ''])) as FilaCsv;
    for (const [titulo, columna] of columnaDeTitulo) {
      fila[columna] = (original[titulo] ?? '').trim();
    }
    return fila;
  });
  return { filas };
}

/** Descarga un CSV (separado por ; y con BOM, para que Excel en España lo abra bien) */
function descargarCsv(nombreArchivo: string, filas: string[][]) {
  const contenido = '\uFEFF' + Papa.unparse(filas, { delimiter: ';' });
  const blob = new Blob([contenido], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const enlace = document.createElement('a');
  enlace.href = url;
  enlace.download = nombreArchivo;
  document.body.appendChild(enlace);
  enlace.click();
  enlace.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function descargarPlantilla() {
  descargarCsv('plantilla-alta-retup.csv', [
    [...COLUMNAS],
    ['María', 'García', 'López', 'maria.garcia@empresa.com', 'Comercial', 'Comercial A', 'Ejecutiva comercial', '01/09/2026'],
  ]);
}

/** Minutos aproximados de importación (~0,5 s por persona) */
function minutosEstimados(personas: number): number {
  return Math.max(1, Math.ceil((personas * 0.5) / 60));
}

// ───────────── Ventana ─────────────
interface PropsImportarCsv {
  alCerrar: () => void;
}

export default function ImportarCsv({ alCerrar }: PropsImportarCsv) {
  const refDialogo = useRef<HTMLDialogElement>(null);
  const refArchivo = useRef<HTMLInputElement>(null);
  const queryClient = useQueryClient();

  const [nombreArchivo, setNombreArchivo] = useState<string | null>(null);
  const [filas, setFilas] = useState<FilaCsv[] | null>(null);
  const [errorArchivo, setErrorArchivo] = useState<string | null>(null);
  const [leyendo, setLeyendo] = useState(false);
  const [soloErrores, setSoloErrores] = useState(true);
  const [descargado, setDescargado] = useState(false);

  useEffect(() => {
    const dialogo = refDialogo.current;
    if (dialogo && !dialogo.open) dialogo.showModal();
  }, []);

  const RUTA = '/dashboard/mantenimiento/usuarios/csv';

  const revision = useMutation({
    mutationFn: (f: FilaCsv[]) =>
      apiFetch<RespuestaRevision>(RUTA, { metodo: 'POST', cuerpo: { simular: true, filas: f } }),
  });

  const importacion = useMutation({
    mutationFn: (f: FilaCsv[]) =>
      apiFetch<RespuestaImportacion>(RUTA, { metodo: 'POST', cuerpo: { simular: false, filas: f } }),
    // También si falla: puede haber creado departamentos o algunas personas
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['mantenimiento'] });
    },
  });

  async function leerArchivo(archivo: File | null) {
    revision.reset();
    importacion.reset();
    setFilas(null);
    setErrorArchivo(null);
    setDescargado(false);
    setSoloErrores(true);
    if (!archivo) return;

    setNombreArchivo(archivo.name);
    setLeyendo(true);
    try {
      const resultado = interpretarCsv(await leerTexto(archivo));
      if ('error' in resultado) {
        setErrorArchivo(resultado.error);
        return;
      }
      setFilas(resultado.filas);
      revision.mutate(resultado.filas);
    } catch {
      setErrorArchivo('No se pudo leer el archivo. Comprueba que es un archivo CSV.');
    } finally {
      setLeyendo(false);
      // Permite volver a elegir el mismo archivo después de corregirlo
      if (refArchivo.current) refArchivo.current.value = '';
    }
  }

  function descargarPasswords(resultado: RespuestaImportacion) {
    const fecha = new Date().toISOString().slice(0, 10);
    descargarCsv(`contrasenas-temporales-${fecha}.csv`, [
      ['nombre', 'email', 'contraseña_temporal'],
      ...resultado.filas
        .filter((f) => f.estado === 'creada')
        .map((f) => [f.nombre, f.email, f.password_temporal ?? '']),
    ]);
    setDescargado(true);
  }

  const datosRevision = revision.data;
  const datosImportacion = importacion.data;
  const creadas = datosImportacion?.resumen.creadas ?? 0;
  const debeDescargar = Boolean(datosImportacion) && creadas > 0 && !descargado;
  const revisando = leyendo || revision.isPending;
  const errorGeneral = errorArchivo ?? revision.error?.message ?? importacion.error?.message ?? null;

  const filasRevisionVisibles = datosRevision
    ? soloErrores && datosRevision.resumen.con_errores > 0
      ? datosRevision.filas.filter((f) => f.errores.length > 0)
      : datosRevision.filas
    : [];

  return (
    <dialog
      ref={refDialogo}
      className="alta imcsv"
      aria-labelledby="imcsv-titulo"
      onClose={alCerrar}
      onCancel={(ev) => {
        // No se cierra con Esc mientras importa ni sin descargar las contraseñas
        if (importacion.isPending || debeDescargar) ev.preventDefault();
      }}
    >
      <div className="alta__contenido">
        <h2 id="imcsv-titulo" className="alta__titulo">
          Importar personas desde CSV
        </h2>

        {/* ═════════ RESULTADO DE LA IMPORTACIÓN ═════════ */}
        {datosImportacion ? (
          <>
            <div className="imcsv__resumen">
              <div className="imcsv__dato imcsv__dato--bien">
                <strong>{creadas}</strong>
                <span>creadas como Invitado</span>
              </div>
              <div className={`imcsv__dato${(datosImportacion.resumen.fallidas ?? 0) > 0 ? ' imcsv__dato--mal' : ''}`}>
                <strong>{datosImportacion.resumen.fallidas ?? 0}</strong>
                <span>no se pudieron crear</span>
              </div>
            </div>

            {creadas > 0 && (
              <div className="imcsv__aviso">
                <p>
                  <strong>Descarga ahora el archivo con las contraseñas temporales.</strong> Es la única
                  vez que se pueden obtener. Entrégaselas a cada persona por un canal seguro y{' '}
                  <strong>borra el archivo</strong> cuando termines.
                </p>
                <button type="button" className="alta__boton" onClick={() => descargarPasswords(datosImportacion)}>
                  {descargado ? '✅ Descargado · Descargar otra vez' : 'Descargar contraseñas temporales'}
                </button>
              </div>
            )}

            <div className="imcsv__tabla-marco">
              <table className="imcsv__tabla">
                <thead>
                  <tr>
                    <th>Fila</th>
                    <th>Persona</th>
                    <th>Resultado</th>
                  </tr>
                </thead>
                <tbody>
                  {datosImportacion.filas.map((f) => (
                    <tr key={f.fila}>
                      <td>{f.fila}</td>
                      <td>
                        <strong>{f.nombre}</strong>
                        <span className="imcsv__email">{f.email}</span>
                      </td>
                      <td>
                        {f.estado === 'creada' ? (
                          <span className="imcsv__ok">✅ Creada</span>
                        ) : (
                          <span className="imcsv__error">❌ {f.error}</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="alta__acciones">
              <button
                type="button"
                className="alta__boton"
                onClick={() => refDialogo.current?.close()}
                disabled={debeDescargar}
                title={debeDescargar ? 'Descarga antes las contraseñas' : undefined}
              >
                {debeDescargar ? 'Descarga antes las contraseñas' : 'Cerrar'}
              </button>
            </div>
          </>
        ) : (
          /* ═════════ ELEGIR ARCHIVO Y REVISAR ═════════ */
          <>
            <p className="alta__explicacion">
              La primera fila del archivo debe tener los títulos de las columnas:{' '}
              <code className="imcsv__columnas">{COLUMNAS.join(', ')}</code>. Son obligatorias{' '}
              <strong>nombre, apellido1 y email</strong>. La fecha, en formato DD/MM/AAAA. Los
              departamentos y equipos que no existan se crearán. Máximo {MAX_FILAS} personas por archivo.
            </p>

            <div className="imcsv__elegir">
              <button type="button" className="alta__boton alta__boton--secundario" onClick={descargarPlantilla}>
                Descargar plantilla
              </button>
              <button
                type="button"
                className="alta__boton"
                onClick={() => refArchivo.current?.click()}
                disabled={revisando || importacion.isPending}
              >
                {nombreArchivo ? 'Elegir otro archivo' : 'Elegir archivo CSV'}
              </button>
              {nombreArchivo && <span className="imcsv__archivo">📄 {nombreArchivo}</span>}
              <input
                ref={refArchivo}
                type="file"
                accept=".csv,text/csv"
                hidden
                onChange={(ev) => void leerArchivo(ev.target.files?.[0] ?? null)}
              />
            </div>

            {errorGeneral && (
              <p className="alta__error" role="alert">
                ❌ {errorGeneral}
              </p>
            )}

            {revisando && <p className="imcsv__mensaje">⏳ Revisando el archivo…</p>}

            {datosRevision && (
              <>
                <div className="imcsv__resumen">
                  <div className="imcsv__dato">
                    <strong>{datosRevision.resumen.total}</strong>
                    <span>personas en el archivo</span>
                  </div>
                  <div className="imcsv__dato imcsv__dato--bien">
                    <strong>{datosRevision.resumen.validas}</strong>
                    <span>correctas</span>
                  </div>
                  <div className={`imcsv__dato${datosRevision.resumen.con_errores > 0 ? ' imcsv__dato--mal' : ''}`}>
                    <strong>{datosRevision.resumen.con_errores}</strong>
                    <span>con errores</span>
                  </div>
                </div>

                {(datosRevision.resumen.departamentos_nuevos.length > 0 ||
                  datosRevision.resumen.equipos_nuevos.length > 0) && (
                  <div className="imcsv__nuevos">
                    {datosRevision.resumen.departamentos_nuevos.length > 0 && (
                      <p>
                        <strong>Departamentos nuevos que se crearán:</strong>{' '}
                        {datosRevision.resumen.departamentos_nuevos.join(', ')}
                      </p>
                    )}
                    {datosRevision.resumen.equipos_nuevos.length > 0 && (
                      <p>
                        <strong>Equipos nuevos que se crearán:</strong>{' '}
                        {datosRevision.resumen.equipos_nuevos.join(', ')}
                      </p>
                    )}
                  </div>
                )}

                {datosRevision.resumen.con_errores > 0 && (
                  <label className="imcsv__casilla">
                    <input
                      type="checkbox"
                      checked={soloErrores}
                      onChange={(ev) => setSoloErrores(ev.target.checked)}
                    />
                    Ver solo las filas con errores
                  </label>
                )}

                <div className="imcsv__tabla-marco">
                  <table className="imcsv__tabla">
                    <thead>
                      <tr>
                        <th>Fila</th>
                        <th>Persona</th>
                        <th>Departamento / equipo</th>
                        <th>Revisión</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filasRevisionVisibles.map((f) => (
                        <tr key={f.fila} className={f.errores.length > 0 ? 'imcsv__fila--mal' : undefined}>
                          <td>{f.fila}</td>
                          <td>
                            <strong>{f.nombre || '—'}</strong>
                            <span className="imcsv__email">{f.email || '—'}</span>
                          </td>
                          <td>
                            {f.departamento ?? '—'}
                            {f.departamento_nuevo && <span className="imcsv__nuevo">nuevo</span>}
                            {f.equipo && (
                              <>
                                {' / '}
                                {f.equipo}
                                {f.equipo_nuevo && <span className="imcsv__nuevo">nuevo</span>}
                              </>
                            )}
                          </td>
                          <td>
                            {f.errores.length === 0 ? (
                              <span className="imcsv__ok">✅ Correcta</span>
                            ) : (
                              <ul className="imcsv__errores">
                                {f.errores.map((e) => (
                                  <li key={e}>❌ {e}</li>
                                ))}
                              </ul>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {datosRevision.resumen.con_errores > 0 && (
                  <p className="imcsv__mensaje">
                    Corrige las filas con errores en tu archivo y pulsa <strong>Elegir otro archivo</strong>{' '}
                    para revisarlo de nuevo.
                  </p>
                )}
              </>
            )}

            {importacion.isPending && filas && (
              <p className="imcsv__mensaje">
                ⏳ Importando {filas.length} personas… puede tardar hasta {minutosEstimados(filas.length)}{' '}
                {minutosEstimados(filas.length) === 1 ? 'minuto' : 'minutos'}. No cierres esta ventana.
              </p>
            )}

            <div className="alta__acciones">
              <button
                type="button"
                className="alta__boton alta__boton--secundario"
                onClick={() => refDialogo.current?.close()}
                disabled={importacion.isPending}
              >
                Cancelar
              </button>
              {datosRevision && filas && (
                <button
                  type="button"
                  className="alta__boton"
                  onClick={() => importacion.mutate(filas)}
                  disabled={datosRevision.resumen.con_errores > 0 || importacion.isPending}
                >
                  {importacion.isPending
                    ? 'Importando…'
                    : `Importar ${datosRevision.resumen.validas} ${datosRevision.resumen.validas === 1 ? 'persona' : 'personas'}`}
                </button>
              )}
            </div>
          </>
        )}
      </div>
    </dialog>
  );
}