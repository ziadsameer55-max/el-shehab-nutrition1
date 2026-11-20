import { type Locale } from '@/lib/access';
import { getMessages, translate } from '@/lib/i18n';
import { getCurrentUser } from '@/lib/server-auth';

export default async function PatientDashboardPage({ params }: { params: Promise<{ locale: Locale }> }) {
  const { locale } = await params;
  const m = getMessages(locale);
  const user = await getCurrentUser(); // guaranteed by the layout guard

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">{m.patient.dashboardTitle}</h1>
      <p>{translate(m, 'patient.greeting', { name: user?.name ?? '' })}</p>
      {user && user.health_profile_completed === false && (
        <p className="card text-sm">{m.patient.healthPrompt}</p>
      )}
      <p className="text-sm text-muted">{m.patient.areaNote}</p>
    </div>
  );
}
