// ═══════════════════════════════════════════════════════════════════
// MANTENIMIENTO · FICHA Y ACCIONES DE UNA PERSONA
// Ventana con los datos de la persona y sus acciones:
//   editar datos · restablecer contraseña · bloquear / desbloquear ·
//   dar de baja / reactivar (según su estado, con confirmación).
// Al terminar una acción, refresca directorio, alertas y catálogo.
// ═══════════════════════════════════════════════════════════════════
import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '../../api/cliente';
import { useSesion } from '../../auth/sesion';
import type { EstadoUsuario, PersonaDirectorio } from './Directorio';
import './Directorio.css';
import './FormularioAlta.css';
import './GestionPersona.css';

// ───────────── Catálogo (departamentos y equipos) ─────────────
interface EquipoCatalogo {
  id: string;
  nombre: string;
  activo: boolean;
  jefe: string | null;
}

interface DepartamentoCatalogo {
  id: string;
  nombre: string;
  activo: boolean;
  equipos: EquipoCatalogo[];
}

interface RespuestaCatalogo {
  success: boolean;
  datos: DepartamentoCatalogo[];
}

// ───────────── Acciones de estado ─────────────
type AccionEstado = 'bloquear' | 'desbloquear' | 'baja' | 'reactivar';

const ACCIONES_POR_ESTADO: Record<EstadoUsuario, AccionEstado[]> = {
  activo: ['bloquear', 'baja'],
  invitado: ['bloquear', 'baja'],
  bloqueado: ['desbloquear', 'baja'],
  baja: ['reactivar'],
};

const INFO_ACCION: Record<
  AccionEstado,
  { boton: string; titulo: string; explicacion: string; peligro: boolean }
> = {
  bloquear: {
    boton: 'Bloquear',
    titulo: '¿Bloquear el acceso?',
    explicacion:
      'No podrá entrar en la app ni en el dashboard hasta que lo desbloquees. Su historial se conserva y aparecerá en "Requiere atención" para que alguien lo revise.',
    peligro: true,
  },
  desbloquear: {
    boton: 'Desbloquear',
    titulo: '¿Desbloquear el acceso?',
    explicacion: 'Podrá volver a entrar con su contraseña actual.',
    peligro: false,
  },
  baja: {
    boton: 'Dar de baja',
    titulo: '¿Dar de baja?',
    explicacion:
      'Úsalo cuando la persona deja la empresa. No podrá entrar y dejará de contar en los indicadores. Su historial se conserva y podrás reactivarla si vuelve.',
    peligro: true,
  },
  reactivar: {
    boton: 'Reactivar',
    titulo: '¿Reactivar a esta persona?',
    explicacion:
      'Volverá a estar activa y podrá entrar con su contraseña. Si no la recuerda, restablécela después.',
    peligro: false,
  },
};

const ETIQUETA_ESTADO: Record<EstadoUsuario, string> = {
  activo: 'Activo',
  invitado: 'Invitado',
  bloqueado: 'Bloqueado',
  baja: 'De baja',
};

// ───────────── Qué se está mostrando en la ventana ─────────────
type Vista =
  | { tipo: 'ficha' }
  | { tipo: 'editar' }
  | { tipo: 'confirmar'; accion: AccionEstado }
  | { tipo: 'confirmar-reset' }
  | { tipo: 'password'; password: string };

interface DatosEdicion {
  first_name: string;
  last_name_1: string;
  last_name_2: string;
  department_id: string;
  team_id: string;
  job_title: string;
  hire_date: string;
}

/** '2026-10-01' -> '01/10/2026' */
function fechaCorta(fechaIso: string): string {
  const [anio, mes, dia] = fechaIso.slice(0, 10).split('-');
  return `${dia}/${mes}/${anio}`;
}

interface PropsGestionPersona {
  persona: PersonaDirectorio;
  /** Se llama cuando la ventana se ha cerrado */
  alCerrar: () => void;
}

export default function GestionPersona({ persona, alCerrar }: PropsGestionPersona) {
  const refDialogo = useRef<HTMLDialogElement>(null);
  const queryClient = useQueryClient();
  const miId = useSesion((s) => s.sesion?.perfil.usuario.id ?? null);
  const esYo = persona.id === miId;
  const estado: EstadoUsuario = persona.estado ?? 'activo';

  const [vista, setVista] = useState<Vista>({ tipo: 'ficha' });
  const [copiada, setCopiada] = useState(false);
  const [datos, setDatos] = useState<DatosEdicion>({
    first_name: persona.first_name ?? '',
    last_name_1: persona.last_name_1 ?? '',
    last_name_2: persona.last_name_2 ?? '',
    department_id: persona.departamento_id ?? '',
    team_id: persona.equipo_id ?? '',
    job_title: persona.cargo ?? '',
    hire_date: persona.fecha_ingreso ? persona.fecha_ingreso.slice(0, 10) : '',
  });

  // Abrir la ventana en modo "modal" al aparecer
  useEffect(() => {
    const dialogo = refDialogo.current;
    if (dialogo && !dialogo.open) dialogo.showModal();
  }, []);

  // El catálogo solo se pide al entrar en "Editar datos"
  const catalogo = useQuery({
    queryKey: ['mantenimiento', 'catalogo'],
    queryFn: () => apiFetch<RespuestaCatalogo>('/dashboard/mantenimiento/catalogo'),
    enabled: vista.tipo === 'editar',
  });
  // Se muestran los activos y, si ya tenía uno inactivo asignado, también ese
  const departamentos = (catalogo.data?.datos ?? []).filter(
    (d) => d.activo || d.id === datos.department_id,
  );
  const equiposDelDepartamento =
    departamentos
      .find((d) => d.id === datos.department_id)
      ?.equipos.filter((e) => e.activo || e.id === datos.team_id) ?? [];

  function refrescar() {
    void queryClient.invalidateQueries({ queryKey: ['mantenimiento'] });
  }

  function cerrar() {
    refDialogo.current?.close();
  }

  // ───────────── Llamadas al backend ─────────────
  const cambioEstado = useMutation({
    mutationFn: (accion: AccionEstado) =>
      apiFetch<{ success: boolean }>(`/dashboard/mantenimiento/usuarios/${persona.id}/estado`, {
        metodo: 'POST',
        cuerpo: { accion },
      }),
    onSuccess: () => {
      refrescar();
      cerrar();
    },
  });

  const restablecer = useMutation({
    mutationFn: () =>
      apiFetch<{ success: boolean; password_temporal: string }>(
        `/dashboard/mantenimiento/usuarios/${persona.id}/restablecer-password`,
        { metodo: 'POST' },
      ),
    onSuccess: (respuesta) => {
      refrescar();
      setVista({ tipo: 'password', password: respuesta.password_temporal });
    },
  });

  const edicion = useMutation({
    mutationFn: (d: DatosEdicion) =>
      apiFetch<{ success: boolean }>(`/dashboard/mantenimiento/usuarios/${persona.id}`, {
        metodo: 'PUT',
        cuerpo: {
          first_name: d.first_name,
          last_name_1: d.last_name_1,
          last_name_2: d.last_name_2 || null,
          department_id: d.department_id || null,
          team_id: d.team_id || null,
          job_title: d.job_title || null,
          hire_date: d.hire_date || null,
        },
      }),
    onSuccess: () => {
      refrescar();
      cerrar();
    },
  });

  const ocupado = cambioEstado.isPending || restablecer.isPending || edicion.isPending;
  const errorActual = cambioEstado.error ?? restablecer.error ?? edicion.error;

  /** Cambia de vista y borra errores de intentos anteriores */
  function irA(nueva: Vista) {
    cambioEstado.reset();
    restablecer.reset();
    edicion.reset();
    setVista(nueva);
  }

  function cambiar(campo: keyof DatosEdicion, valor: string) {
    setDatos((anterior) => ({
      ...anterior,
      [campo]: valor,
      ...(campo === 'department_id' ? { team_id: '' } : {}),
    }));
  }

  async function copiarPassword(password: string) {
    try {
      await navigator.clipboard.writeText(password);
      setCopiada(true);
    } catch {
      setCopiada(false);
    }
  }

  const mensajeError = errorActual && (
    <p className="alta__error" role="alert">
      ❌ {errorActual.message}
    </p>
  );

  const accionAConfirmar = vista.tipo === 'confirmar' ? vista.accion : null;
  const passwordMostrada = vista.tipo === 'password' ? vista.password : null;

  return (
    <dialog
      ref={refDialogo}
      className="alta"
      aria-labelledby="gestion-titulo"
      onClose={alCerrar}
      onCancel={(ev) => {
        // Con Esc no se cierra mientras guarda ni mientras muestra una contraseña
        if (ocupado || vista.tipo === 'password') ev.preventDefault();
      }}
    >
      {/* ───────────── FICHA ───────────── */}
      {vista.tipo === 'ficha' && (
        <div className="alta__contenido">
          <div className="gestion__cabecera">
            <h2 id="gestion-titulo" className="alta__titulo">
              {persona.nombre}
            </h2>
            <span className={`directorio__estado directorio__estado--${estado}`}>
              {ETIQUETA_ESTADO[estado] ?? estado}
            </span>
          </div>

          <dl className="gestion__datos">
            <div>
              <dt>Email</dt>
              <dd>{persona.email}</dd>
            </div>
            <div>
              <dt>Cargo</dt>
              <dd>{persona.cargo ?? '—'}</dd>
            </div>
            <div>
              <dt>Departamento</dt>
              <dd>{persona.departamento ?? '—'}</dd>
            </div>
            <div>
              <dt>Equipo</dt>
              <dd>{persona.equipo ?? '—'}</dd>
            </div>
            <div>
              <dt>Fecha de ingreso</dt>
              <dd>{persona.fecha_ingreso ? fechaCorta(persona.fecha_ingreso) : '—'}</dd>
            </div>
            <div>
              <dt>Jefe de</dt>
              <dd>{persona.jefe_de.length > 0 ? persona.jefe_de.join(', ') : '—'}</dd>
            </div>
          </dl>

          {persona.reset_solicitado && (
            <p className="gestion__aviso">🔑 Esta persona pidió restablecer su contraseña.</p>
          )}

          <div className="gestion__acciones">
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={() => irA({ tipo: 'editar' })}
            >
              Editar datos
            </button>
            {estado !== 'baja' && (
              <button
                type="button"
                className="alta__boton alta__boton--secundario"
                onClick={() => irA({ tipo: 'confirmar-reset' })}
              >
                Restablecer contraseña
              </button>
            )}
            {!esYo &&
              ACCIONES_POR_ESTADO[estado].map((accion) => (
                <button
                  key={accion}
                  type="button"
                  className={`alta__boton alta__boton--secundario${INFO_ACCION[accion].peligro ? ' gestion__boton--secundario-peligro' : ''}`}
                  onClick={() => irA({ tipo: 'confirmar', accion })}
                >
                  {INFO_ACCION[accion].boton}
                </button>
              ))}
          </div>

          {esYo && (
            <p className="alta__explicacion">
              Esta es tu propia cuenta: no puedes bloquearte ni darte de baja a ti mismo.
            </p>
          )}

          <div className="alta__acciones">
            <button type="button" className="alta__boton" onClick={cerrar}>
              Cerrar
            </button>
          </div>
        </div>
      )}

      {/* ───────────── CONFIRMAR CAMBIO DE ESTADO ───────────── */}
      {accionAConfirmar && (
        <div className="alta__contenido">
          <h2 id="gestion-titulo" className="alta__titulo">
            {INFO_ACCION[accionAConfirmar].titulo}
          </h2>
          <p className="alta__persona">
            <strong>{persona.nombre}</strong>
            <span>{persona.email}</span>
          </p>
          <p className="alta__explicacion">{INFO_ACCION[accionAConfirmar].explicacion}</p>
          {mensajeError}
          <div className="alta__acciones">
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={() => irA({ tipo: 'ficha' })}
              disabled={ocupado}
            >
              Volver
            </button>
            <button
              type="button"
              className={`alta__boton${INFO_ACCION[accionAConfirmar].peligro ? ' gestion__boton--peligro' : ''}`}
              onClick={() => cambioEstado.mutate(accionAConfirmar)}
              disabled={ocupado}
            >
              {cambioEstado.isPending ? 'Guardando…' : INFO_ACCION[accionAConfirmar].boton}
            </button>
          </div>
        </div>
      )}

      {/* ───────────── CONFIRMAR RESTABLECER CONTRASEÑA ───────────── */}
      {vista.tipo === 'confirmar-reset' && (
        <div className="alta__contenido">
          <h2 id="gestion-titulo" className="alta__titulo">
            ¿Restablecer la contraseña?
          </h2>
          <p className="alta__persona">
            <strong>{persona.nombre}</strong>
            <span>{persona.email}</span>
          </p>
          <p className="alta__explicacion">
            Se generará una contraseña temporal nueva y <strong>la actual dejará de funcionar</strong>.
            Tendrás que entregársela a la persona por un canal seguro.
          </p>
          {mensajeError}
          <div className="alta__acciones">
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={() => irA({ tipo: 'ficha' })}
              disabled={ocupado}
            >
              Volver
            </button>
            <button
              type="button"
              className="alta__boton"
              onClick={() => restablecer.mutate()}
              disabled={ocupado}
            >
              {restablecer.isPending ? 'Generando…' : 'Generar contraseña temporal'}
            </button>
          </div>
        </div>
      )}

      {/* ───────────── CONTRASEÑA TEMPORAL (solo esta vez) ───────────── */}
      {passwordMostrada && (
        <div className="alta__contenido">
          <h2 id="gestion-titulo" className="alta__titulo">
            ✅ Contraseña restablecida
          </h2>
          <p className="alta__persona">
            <strong>{persona.nombre}</strong>
            <span>{persona.email}</span>
          </p>
          <p className="alta__explicacion">
            Esta es su nueva <strong>contraseña temporal</strong>. <strong>Solo se muestra ahora</strong>
            : cópiala y entrégasela por un canal seguro.
          </p>
          <div className="alta__password">
            <code>{passwordMostrada}</code>
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={() => copiarPassword(passwordMostrada)}
            >
              {copiada ? '¡Copiada!' : 'Copiar'}
            </button>
          </div>
          <div className="alta__acciones">
            <button type="button" className="alta__boton" onClick={cerrar}>
              Hecho, ya la he guardado
            </button>
          </div>
        </div>
      )}

      {/* ───────────── EDITAR DATOS ───────────── */}
      {vista.tipo === 'editar' && (
        <form
          className="alta__contenido"
          onSubmit={(ev) => {
            ev.preventDefault();
            edicion.mutate(datos);
          }}
        >
          <h2 id="gestion-titulo" className="alta__titulo">
            Editar datos
          </h2>
          <p className="alta__explicacion">
            {persona.email} · El email no se puede cambiar. Los campos con * son obligatorios.
          </p>

          <div className="alta__rejilla">
            <label className="alta__campo">
              <span>Nombre *</span>
              <input
                required
                maxLength={60}
                value={datos.first_name}
                onChange={(ev) => cambiar('first_name', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Primer apellido *</span>
              <input
                required
                maxLength={60}
                value={datos.last_name_1}
                onChange={(ev) => cambiar('last_name_1', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Segundo apellido</span>
              <input
                maxLength={60}
                value={datos.last_name_2}
                onChange={(ev) => cambiar('last_name_2', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Cargo</span>
              <input
                maxLength={120}
                value={datos.job_title}
                onChange={(ev) => cambiar('job_title', ev.target.value)}
              />
            </label>

            <label className="alta__campo">
              <span>Departamento</span>
              <select
                value={datos.department_id}
                onChange={(ev) => cambiar('department_id', ev.target.value)}
                disabled={catalogo.isPending}
              >
                <option value="">{catalogo.isPending ? 'Cargando…' : 'Sin departamento'}</option>
                {departamentos.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.nombre}
                  </option>
                ))}
              </select>
            </label>

            <label className="alta__campo">
              <span>Equipo</span>
              <select
                value={datos.team_id}
                onChange={(ev) => cambiar('team_id', ev.target.value)}
                disabled={!datos.department_id || equiposDelDepartamento.length === 0}
              >
                <option value="">
                  {!datos.department_id
                    ? 'Elige antes un departamento'
                    : equiposDelDepartamento.length === 0
                      ? 'Este departamento no tiene equipos'
                      : 'Sin equipo'}
                </option>
                {equiposDelDepartamento.map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.nombre}
                    {e.jefe ? ` (jefe: ${e.jefe})` : ''}
                  </option>
                ))}
              </select>
            </label>

            <label className="alta__campo">
              <span>Fecha de ingreso</span>
              <input
                type="date"
                value={datos.hire_date}
                onChange={(ev) => cambiar('hire_date', ev.target.value)}
              />
            </label>
          </div>

          {catalogo.isError && (
            <p className="alta__error" role="alert">
              No se pudieron cargar los departamentos.
            </p>
          )}
          {mensajeError}

          <div className="alta__acciones">
            <button
              type="button"
              className="alta__boton alta__boton--secundario"
              onClick={() => irA({ tipo: 'ficha' })}
              disabled={ocupado}
            >
              Volver
            </button>
            <button type="submit" className="alta__boton" disabled={ocupado}>
              {edicion.isPending ? 'Guardando…' : 'Guardar cambios'}
            </button>
          </div>
        </form>
      )}
    </dialog>
  );
}