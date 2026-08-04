// src/pages/_app.jsx
import '../styles/globals.css';
import ProtectedRoute from '../components/ProtectedRoute';

const protectedPaths = [
  '/agency',
  '/agency/dashboard',
  '/agency/transactions',
  '/admin',
  '/gov'
];

function MyApp({ Component, pageProps, router }) {
  const path = router.pathname;
  const needsAuth = protectedPaths.some(p => path.startsWith(p));

  if (needsAuth) {
    // السماح للأدوار agency, gov, admin
    return (
      <ProtectedRoute allowedRoles={['agency', 'gov', 'admin']}>
        <Component {...pageProps} />
      </ProtectedRoute>
    );
  }

  return <Component {...pageProps} />;
}

export default MyApp;
