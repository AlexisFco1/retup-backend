// ═══════════════════════════════════════════════════════════════════
// MANTENIMIENTO · REQUIERE ATENCIÓN
// Bandeja de avisos sobre usuarios de la empresa, por prioridad:
//   1 (alta): pidió restablecer contraseña · usuario bloqueado
//   2 (pendiente): invitado que todavía no ha entrado nunca
// Se actualiza sola cada minuto.
// ═══════════════════════════════════════════════════════════════════
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { apiFetch } from '../../api/cliente';
import GestionPersona from './GestionPersona';
import type { PersonaDirectorio } from './Directorio';
import './RequiereAtencion.css';

// ───────────── Forma de la respuesta del backend ─────────────
type TipoAlerta = 'restablecer' | 'bloqueado' | 'sin_registrar';

interface Alerta {
  prioridad: number;
  tipo: TipoAlerta;
  usuario_id: string;
  email: string;
  nombre: string;
  cargo: string | null;
  departamento: string | null;
  desde: string | null;
  dias: number | null;
}

interface RespuestaAlertas {
  success: boolean;
  datos: Alerta[];
}

// ───────────── Textos de cada tipo de aviso ─────────────
const INFO_TIPO: Record<TipoAlerta, { titulo: string; queHacer: string }> = {
  restablecer: {
    titulo: 'Pidió restablecer su contraseña',
    queHacer: 'Genera una contraseña temporal y entrégasela en persona o por un canal seguro.',
  },
  bloqueado: {
    titulo: 'Usuario bloqueado',
    queHacer: 'Revisa el motivo y decide si debe desbloquearse o darse de baja.',
  },
  sin_registrar: {
    titulo: 'Invitado que aún no ha entrado',
    queHacer: 'Recuérdale que descargue la app y entre con su contraseña temporal.',
  },
};

/** 0 -> "Hoy", 1 -> "Hace 1 día", 5 -> "Hace 5 días" */
function textoDias(dias: number | null): string | null {
  if (dias === null) return null;
  if (dias <= 0) return 'Hoy';
  return dias === 1 ? 'Hace 1 día' : `Hace ${dias} días`;
}

// ───────────── Lista de avisos de un grupo ─────────────
interface PropsListaAlertas {
  alertas: Alerta[];
  /** false mientras se carga el directorio (los botones se desactivan) */
  listo: boolean;
  alAtender: (usuarioId: string) => void;
}

function ListaAlertas({ alertas, listo, alAtender }: PropsListaAlertas) {
  return (
    <ul className="atencion__lista">
      {alertas.map((a) => {
        const info = INFO_TIPO[a.tipo];
        const antiguedad = textoDias(a.dias);
        return (
          <li key={`${a.tipo}-${a.usuario_id}`} className={`atencion__alerta atencion__alerta--${a.tipo}`}>
            <div className="atencion__alerta-tipo">
              <strong>{info?.titulo ?? a.tipo}</strong>
              {antiguedad && <span>{antiguedad}</span>}
            </div>
            <div className="atencion__alerta-persona">
              <strong>{a.nombre}</strong>
              <span>
                {a.email}
                {a.departamento ? ` · ${a.departamento}` : ''}
                {a.cargo ? ` · ${a.cargo}` : ''}
              </span>
            </div>
                        {info && <p className="atencion__alerta-accion">{info.queHacer}</p>}
            <div className="atencion__alerta-boton">
              <button
                type="button"
                onClick={() => alAtender(a.usuario_id)}
                disabled={!listo}
                aria-label={`Atender a ${a.nombre}`}
              >
                Atender
              </button>
            </div>
          </li>
        );
      })}
    </ul>
  );
}

// ───────────── Pantalla ─────────────
export default function RequiereAtencion() {
  const consulta = useQuery({
    queryKey: ['mantenimiento', 'alertas'],
    queryFn: () => apiFetch<RespuestaAlertas>('/dashboard/mantenimiento/alertas'),
        // Se vuelve a consultar cada minuto mientras la pantalla esté abierta
    refetchInterval: 60_000,
  });

  // Directorio completo (misma clave que la pantalla Directorio: se comparte en memoria)
  const directorio = useQuery({
    queryKey: ['mantenimiento', 'directorio'],
    queryFn: () =>
      apiFetch<{ success: boolean; datos: PersonaDirectorio[] }>('/dashboard/mantenimiento/directorio'),
  });

  // Persona cuya ficha está abierta (null = ninguna)
  const [atendiendo, setAtendiendo] = useState<string | null>(null);
  const personaAtendida = directorio.data?.datos.find((p) => p.id === atendiendo) ?? null;
  const directorioListo = Boolean(directorio.data);

  if (consulta.isPending) {
    return <p className="atencion__estado-carga">⏳ Revisando avisos…</p>;
  }
  if (consulta.isError || !consulta.data) {
    return (
      <p className="atencion__estado-carga atencion__estado-carga--error">
        ❌ {consulta.error?.message ?? 'No se pudieron cargar los avisos'}
      </p>
    );
  }

  const alertas = consulta.data.datos;
  const altas = alertas.filter((a) => a.prioridad === 1);
  const pendientes = alertas.filter((a) => a.prioridad !== 1);

  const totalRestablecer = alertas.filter((a) => a.tipo === 'restablecer').length;
  const totalBloqueados = alertas.filter((a) => a.tipo === 'bloqueado').length;
  const totalSinRegistrar = alertas.filter((a) => a.tipo === 'sin_registrar').length;

  return (
    <div className={`atencion${consulta.isFetching ? ' atencion--actualizando' : ''}`}>
      <header className="atencion__cabecera">
        <p className="atencion__miga">Mantenimiento</p>
        <h1 className="atencion__titulo">Requiere atención</h1>
        <p className="atencion__subtitulo">
                   Personas de tu empresa con alguna gestión pendiente, de la más urgente a la menos.
        </p>
      </header>

      {personaAtendida && (
        <GestionPersona persona={personaAtendida} alCerrar={() => setAtendiendo(null)} />
      )}

      {/* ── Resumen ── */}
      <section className="atencion__resumen" aria-label="Resumen de avisos">
        <div className="atencion__contador atencion__contador--alta">
          <strong>{totalRestablecer}</strong>
          <span>Contraseñas por restablecer</span>
        </div>
        <div className="atencion__contador atencion__contador--alta">
          <strong>{totalBloqueados}</strong>
          <span>Usuarios bloqueados</span>
        </div>
        <div className="atencion__contador">
          <strong>{totalSinRegistrar}</strong>
          <span>Invitados sin entrar</span>
        </div>
      </section>

      {alertas.length === 0 ? (
        <section className="atencion__todo-bien">
          <p className="atencion__todo-bien-titulo">✅ Todo en orden</p>
          <p>No hay ninguna gestión pendiente con los usuarios de tu empresa.</p>
          <Link to="/mantenimiento/directorio">Ver el directorio completo →</Link>
        </section>
      ) : (
        <>
          {altas.length > 0 && (
            <section className="atencion__grupo">
              <h2 className="atencion__grupo-titulo atencion__grupo-titulo--alta">
                Prioridad alta <span>{altas.length}</span>
              </h2>
                            <ListaAlertas alertas={altas} listo={directorioListo} alAtender={setAtendiendo} />
            </section>
          )}

          {pendientes.length > 0 && (
            <section className="atencion__grupo">
              <h2 className="atencion__grupo-titulo">
                Pendientes <span>{pendientes.length}</span>
              </h2>
                         <ListaAlertas alertas={pendientes} listo={directorioListo} alAtender={setAtendiendo} />
            </section>
          )}
        </>
      )}
    </div>
  );
}