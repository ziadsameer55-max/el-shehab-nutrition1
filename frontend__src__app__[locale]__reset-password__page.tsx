import { ResetPasswordForm } from '@/components/forms/ResetPasswordForm';

export default async function ResetPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string; email?: string }>;
}) {
  const { token, email } = await searchParams;
  return <ResetPasswordForm token={token} email={email} />;
}
