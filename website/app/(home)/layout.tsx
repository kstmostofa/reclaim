import { FloatingHeader } from '@/components/home/header';

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <>
      <FloatingHeader />
      {children}
    </>
  );
}
