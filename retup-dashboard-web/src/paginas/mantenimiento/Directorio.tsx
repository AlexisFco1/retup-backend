// ═══════════════════════════════════════════════════════════════════
// MANTENIMIENTO · DIRECTORIO DE USUARIOS
// Todas las personas de la empresa del usuario conectado.
// Búsqueda, filtros y orden por columna se hacen en el navegador
// (la lista se descarga una vez; filtrar es instantáneo).
// La empresa la decide el backend desde el token, nunca el navegador.
// ═══════════════════════════════════════════════════════════════════
import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '../../api/cliente';
import { useSesion } from '../../auth/sesion';
import type { NivelAcceso } from '../../auth/sesion';
import './Directorio.css';

// ───────────── Forma de la respuesta del backend ─────────────
type EstadoUsuario = 'activo' | 'invitado' | 'bloqueado' | 'baja';

interface PersonaDirectorio {
  id: string;
  email: string;
  nombre: string;
  first_name: string | null;
  last_name_1: string | null;
  last_name_2: string | null;
  rol_app: string | null;
  cargo: string | null;
  departamento_id: string | null;
  departamento: string | null;
  equipo_id: string | null;
  equipo: string | null;
  jefe_de: string[];
  niveles: NivelAcceso[];
  estado: EstadoUsuario | null;
  fecha_ingreso: string | null;
  creado: string | null;
  ultimo_acceso: string | null;
  reset_solicitado: string | null;
}

interface RespuestaDirectorio {
  success: boolean;
  datos: PersonaDirectorio[];
}

// ───────────── Textos y constantes ─────────────
const ETIQUETA_ESTADO: Record<EstadoUsuario, string> = {
  activo: 'Activo',
  invitado: 'Invitado',
  bloqueado: 'Bloqueado',
  baja: 'De baja',
};

const ETIQUETA_ESTADO_PLURAL: Record<EstadoUsuario, string> = {
  activo: 'Activos',
  invitado: 'Invitados',
  bloqueado: 'Bloqueados',
  baja: 'De baja',
};

const ETIQUETA_NIVEL: Record<NivelAcceso, string> = {
  retup: 'RetUp',
  rrhh_gerencia: 'RRHH · Gerencia',
  jefatura: 'Jefatura',
  mantenimiento: 'Mantenimiento',
};

const ORDEN_ESTADOS: EstadoUsuario[] = ['activo', 'invitado', 'bloqueado', 'baja'];
const NIVELES: NivelAcceso[] = ['retup', 'rrhh_gerencia', 'jefatura', 'mantenimiento'];

const FILAS_POR_PAGINA = 50;
/** Valor de los desplegables para "sin departamento / sin equipo / sin nivel" */
const SIN_VALOR = '__sin__';
/** Valor de los desplegables para "todos" (sin filtrar) */
const TODOS = '';

type Columna = 'nombre' | 'departamento' | 'equipo' | 'cargo' | 'estado' | 'ultimo_acceso';

interface Orden {
  columna: Columna;
  asc: boolean;
}

const formatoFecha = new Intl.DateTimeFormat('es-ES', {
  timeZone: 'Europe/Madrid',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

// ───────────── Ayudantes ─────────────
/** Minúsculas y sin tildes, para buscar "maria" y encontrar "María" */
function normalizar(texto: string | null | undefined): string {
  return (texto ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function textoUltimoAcceso(fecha: string | null): string {
  if (!fecha) return 'Sin registro';
  return formatoFecha.format(new Date(fecha));
}

/** Valor con el que se ordena cada columna (null = celda vacía, siempre al final) */
function valorOrden(p: PersonaDirectorio, columna: Columna): string | number | null {
  switch (columna) {
    case 'nombre':
      return p.nombre;
    case 'departamento':
      return p.departamento;
    case 'equipo':
      return p.equipo;
    case 'cargo':
      return p.cargo;
    case 'estado':
      return p.estado ? ORDEN_ESTADOS.indexOf(p.estado) : null;
    case 'ultimo_acceso':
      return p.ultimo_acceso ? Date.parse(p.ultimo_acceso) : null;
  }
}

function comparar(a: PersonaDirectorio, b: PersonaDirectorio, orden: Orden): number {
  const va = valorOrden(a, orden.columna);
  const vb = valorOrden(b, orden.columna);

  if (va === null && vb === null) return a.nombre.localeCompare(b.nombre, 'es');
  if (va === null) return 1; // vacíos al final, ordenes como ordenes
  if (vb === null) return -1;

  const resultado =
    typeof va === 'number' && typeof vb === 'number'
      ? va - vb
      : String(va).localeCompare(String(vb), 'es', { sensitivity: 'base' });

  if (resultado === 0) return a.nombre.localeCompare(b.nombre, 'es');
  return orden.asc ? resultado : -resultado;
}

// ───────────── Título de columna que ordena al hacer clic ─────────────
interface PropsEncabezado {
  columna: Columna;
  titulo: string;
  orden: Orden;
  alOrdenar: (columna: Columna) => void;
}

function Encabezado({ columna, titulo, orden, alOrdenar }: PropsEncabezado) {
  const activo = orden.columna === columna;
  const sentido: 'ascending' | 'descending' | 'none' = activo
    ? orden.asc
      ? 'ascending'
      : 'descending'
    : 'none';

  return (
    <th aria-sort={sentido}>
      <button
        type="button"
        className={`directorio__orden${activo ? ' directorio__orden--activo' : ''}`}
        onClick={() => alOrdenar(columna)}
      >
        {titulo}
        <span aria-hidden="true" className="directorio__flecha">
          {activo ? (orden.asc ? '▲' : '▼') : '↕'}
        </span>
      </button>
    </th>
  );
}

// ───────────── Pantalla ─────────────
export default function Directorio() {
  const nombreEmpresa = useSesion((s) => s.sesion?.perfil.empresa?.name ?? null);

  const consulta = useQuery({
    queryKey: ['mantenimiento', 'directorio'],
    queryFn: () => apiFetch<RespuestaDirectorio>('/dashboard/mantenimiento/directorio'),
  });
  const personas = consulta.data?.datos;

  const [busqueda, setBusqueda] = useState('');
  const [estado, setEstado] = useState(TODOS);
  const [departamento, setDepartamento] = useState(TODOS);
  const [equipo, setEquipo] = useState(TODOS);
  const [nivel, setNivel] = useState(TODOS);
  const [orden, setOrden] = useState<Orden>({ columna: 'nombre', asc: true });
  const [pagina, setPagina] = useState(1);

  // Opciones de los desplegables, sacadas de los propios datos
  const opciones = useMemo(() => {
    const departamentos = new Set<string>();
    const equipos = new Set<string>();
    let haySinDepartamento = false;
    let haySinEquipo = false;

    for (const p of personas ?? []) {
      if (p.departamento) departamentos.add(p.departamento);
      else haySinDepartamento = true;
      if (p.equipo) equipos.add(p.equipo);
      else haySinEquipo = true;
    }

    const ordenar = (conjunto: Set<string>) =>
      [...conjunto].sort((a, b) => a.localeCompare(b, 'es'));

    return {
      departamentos: ordenar(departamentos),
      equipos: ordenar(equipos),
      haySinDepartamento,
      haySinEquipo,
    };
  }, [personas]);

  // Total de personas por estado (pastillas de arriba)
  const totalesEstado = useMemo(() => {
    const totales: Record<EstadoUsuario, number> = { activo: 0, invitado: 0, bloqueado: 0, baja: 0 };
    for (const p of personas ?? []) {
      if (p.estado && p.estado in totales) totales[p.estado] += 1;
    }
    return totales;
  }, [personas]);

  // Filtrar + ordenar (solo se recalcula si cambia algo de esto)
  const filtradas = useMemo(() => {
    const texto = normalizar(busqueda);

    const resultado = (personas ?? []).filter((p) => {
      if (texto && !normalizar(`${p.nombre} ${p.email} ${p.cargo ?? ''}`).includes(texto)) {
        return false;
      }
      if (estado && p.estado !== estado) return false;
      if (departamento) {
        if (departamento === SIN_VALOR ? p.departamento !== null : p.departamento !== departamento) {
          return false;
        }
      }
      if (equipo) {
        if (equipo === SIN_VALOR ? p.equipo !== null : p.equipo !== equipo) return false;
      }
      if (nivel) {
        if (nivel === SIN_VALOR ? p.niveles.length > 0 : !p.niveles.includes(nivel as NivelAcceso)) {
          return false;
        }
      }
      return true;
    });

    return resultado.sort((a, b) => comparar(a, b, orden));
  }, [personas, busqueda, estado, departamento, equipo, nivel, orden]);

  // Paginación
  const totalPaginas = Math.max(1, Math.ceil(filtradas.length / FILAS_POR_PAGINA));
  const paginaActual = Math.min(pagina, totalPaginas);
  const inicio = (paginaActual - 1) * FILAS_POR_PAGINA;
  const visibles = filtradas.slice(inicio, inicio + FILAS_POR_PAGINA);

  const hayFiltros = Boolean(busqueda || estado || departamento || equipo || nivel);

  function limpiarFiltros() {
    setBusqueda('');
    setEstado(TODOS);
    setDepartamento(TODOS);
    setEquipo(TODOS);
    setNivel(TODOS);
    setPagina(1);
  }

  function ordenarPor(columna: Columna) {
    setOrden((anterior) =>
      anterior.columna === columna
        ? { columna, asc: !anterior.asc }
        : // El último acceso empieza por el más reciente; el resto, de la A a la Z
          { columna, asc: columna !== 'ultimo_acceso' },
    );
    setPagina(1);
  }

  // ───────────── Estados: cargando / error / vacío ─────────────
  if (consulta.isPending) {
    return <p className="directorio__estado-carga">⏳ Cargando el directorio…</p>;
  }
  if (consulta.isError || !personas) {
    return (
      <p className="directorio__estado-carga directorio__estado-carga--error">
        ❌ {consulta.error?.message ?? 'No se pudo cargar el directorio'}
      </p>
    );
  }

  return (
    <div className={`directorio${consulta.isFetching ? ' directorio--actualizando' : ''}`}>
      <header className="directorio__cabecera">
        <p className="directorio__miga">Mantenimiento</p>
        <h1 className="directorio__titulo">Directorio de usuarios</h1>
        <p className="directorio__subtitulo">
          {personas.length} {personas.length === 1 ? 'persona' : 'personas'}
          {nombreEmpresa ? ` en ${nombreEmpresa}` : ''}
        </p>
      </header>

      {/* ── Pastillas de estado (clic = filtrar por ese estado) ── */}
      <div className="directorio__pastillas" role="group" aria-label="Filtrar por estado">
        {ORDEN_ESTADOS.map((e) => (
          <button
            key={e}
            type="button"
            aria-pressed={estado === e}
            className={`directorio__pastilla directorio__pastilla--${e}${estado === e ? ' directorio__pastilla--elegida' : ''}`}
            onClick={() => {
              setEstado(estado === e ? TODOS : e);
              setPagina(1);
            }}
          >
            <strong>{totalesEstado[e]}</strong>
            <span>{ETIQUETA_ESTADO_PLURAL[e]}</span>
          </button>
        ))}
      </div>

      {/* ── Buscador y filtros ── */}
      <section className="directorio__herramientas" aria-label="Buscar y filtrar">
        <label className="directorio__campo directorio__campo--busqueda">
          <span>Buscar</span>
          <input
            type="search"
            placeholder="Nombre, email o cargo"
            value={busqueda}
            onChange={(ev) => {
              setBusqueda(ev.target.value);
              setPagina(1);
            }}
          />
        </label>

        <label className="directorio__campo">
          <span>Estado</span>
          <select
            value={estado}
            onChange={(ev) => {
              setEstado(ev.target.value);
              setPagina(1);
            }}
          >
            <option value={TODOS}>Todos</option>
            {ORDEN_ESTADOS.map((e) => (
              <option key={e} value={e}>
                {ETIQUETA_ESTADO[e]}
              </option>
            ))}
          </select>
        </label>

        <label className="directorio__campo">
          <span>Departamento</span>
          <select
            value={departamento}
            onChange={(ev) => {
              setDepartamento(ev.target.value);
              setPagina(1);
            }}
          >
            <option value={TODOS}>Todos</option>
            {opciones.departamentos.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
            {opciones.haySinDepartamento && <option value={SIN_VALOR}>Sin departamento</option>}
          </select>
        </label>

        <label className="directorio__campo">
          <span>Equipo</span>
          <select
            value={equipo}
            onChange={(ev) => {
              setEquipo(ev.target.value);
              setPagina(1);
            }}
          >
            <option value={TODOS}>Todos</option>
            {opciones.equipos.map((eq) => (
              <option key={eq} value={eq}>
                {eq}
              </option>
            ))}
            {opciones.haySinEquipo && <option value={SIN_VALOR}>Sin equipo</option>}
          </select>
        </label>

        <label className="directorio__campo">
          <span>Acceso al dashboard</span>
          <select
            value={nivel}
            onChange={(ev) => {
              setNivel(ev.target.value);
              setPagina(1);
            }}
          >
            <option value={TODOS}>Todos</option>
            {NIVELES.map((n) => (
              <option key={n} value={n}>
                {ETIQUETA_NIVEL[n]}
              </option>
            ))}
            <option value={SIN_VALOR}>Sin acceso (solo app)</option>
          </select>
        </label>

        <button
          type="button"
          className="directorio__limpiar"
          onClick={limpiarFiltros}
          disabled={!hayFiltros}
        >
          Limpiar filtros
        </button>
      </section>

      {/* ── Tabla ── */}
      <section className="directorio__tabla-marco">
        <table className="directorio__tabla">
          <caption className="directorio__solo-lectores">
            Directorio de usuarios. Haz clic en el título de una columna para ordenar.
          </caption>
          <thead>
            <tr>
              <Encabezado columna="nombre" titulo="Persona" orden={orden} alOrdenar={ordenarPor} />
              <Encabezado columna="departamento" titulo="Departamento" orden={orden} alOrdenar={ordenarPor} />
              <Encabezado columna="equipo" titulo="Equipo" orden={orden} alOrdenar={ordenarPor} />
              <Encabezado columna="cargo" titulo="Cargo" orden={orden} alOrdenar={ordenarPor} />
              <th>Acceso al dashboard</th>
              <Encabezado columna="estado" titulo="Estado" orden={orden} alOrdenar={ordenarPor} />
              <Encabezado columna="ultimo_acceso" titulo="Último acceso" orden={orden} alOrdenar={ordenarPor} />
            </tr>
          </thead>
          <tbody>
            {visibles.length === 0 ? (
              <tr>
                <td colSpan={7} className="directorio__sin-resultados">
                  {personas.length === 0
                    ? 'Todavía no hay personas dadas de alta en tu empresa.'
                    : 'Ninguna persona coincide con la búsqueda o los filtros.'}
                </td>
              </tr>
            ) : (
              visibles.map((p) => (
                <tr key={p.id}>
                  <td>
                    <div className="directorio__persona">
                      <strong>{p.nombre}</strong>
                      <span>{p.email}</span>
                    </div>
                  </td>
                  <td>{p.departamento ?? <span className="directorio__vacio">—</span>}</td>
                  <td>{p.equipo ?? <span className="directorio__vacio">—</span>}</td>
                  <td>{p.cargo ?? <span className="directorio__vacio">—</span>}</td>
                  <td>
                    {p.niveles.length === 0 ? (
                      <span className="directorio__vacio">Solo app</span>
                    ) : (
                      <div className="directorio__niveles">
                        {p.niveles.map((n) => (
                          <span key={n} className="directorio__nivel">
                            {ETIQUETA_NIVEL[n] ?? n}
                          </span>
                        ))}
                      </div>
                    )}
                    {p.jefe_de.length > 0 && (
                      <p className="directorio__jefe-de">Jefe de: {p.jefe_de.join(', ')}</p>
                    )}
                  </td>
                  <td>
                    {p.estado ? (
                      <span className={`directorio__estado directorio__estado--${p.estado}`}>
                        {ETIQUETA_ESTADO[p.estado] ?? p.estado}
                      </span>
                    ) : (
                      <span className="directorio__vacio">—</span>
                    )}
                    {p.reset_solicitado && (
                      <p className="directorio__aviso">Pidió restablecer contraseña</p>
                    )}
                  </td>
                  <td className={p.ultimo_acceso ? undefined : 'directorio__vacio'}>
                    {textoUltimoAcceso(p.ultimo_acceso)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </section>

      {/* ── Pie: recuento y paginación ── */}
      <footer className="directorio__pie">
        <p>
          {filtradas.length === 0
            ? 'Sin resultados'
            : `Mostrando ${inicio + 1}–${inicio + visibles.length} de ${filtradas.length}`}
          {hayFiltros && ` (filtrado de ${personas.length})`}
        </p>
        {totalPaginas > 1 && (
          <nav className="directorio__paginas" aria-label="Paginación">
            <button
              type="button"
              onClick={() => setPagina(paginaActual - 1)}
              disabled={paginaActual === 1}
            >
              ← Anterior
            </button>
            <span>
              Página {paginaActual} de {totalPaginas}
            </span>
            <button
              type="button"
              onClick={() => setPagina(paginaActual + 1)}
              disabled={paginaActual === totalPaginas}
            >
              Siguiente →
            </button>
          </nav>
        )}
      </footer>

      <p className="directorio__nota">
        "Último acceso" cuenta desde que la app empezó a registrar actividad. Quien no ha abierto la
        app desde entonces aparece como "Sin registro".
      </p>
    </div>
  );
}