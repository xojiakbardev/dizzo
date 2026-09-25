export function useScrollTo() {
  const router = useRouter();

  function scrollTo(elementId: string, offset = 90) {
    if (import.meta.server) return;

    const performScroll = () => {
      const el = document.getElementById(elementId);
      if (el) {
        const top = el.getBoundingClientRect().top + window.scrollY - offset;
        window.scrollTo({
          top,
          behavior: 'smooth',
        });
      }
    };

    if (router.currentRoute.value.path !== '/') {
      Promise.resolve(navigateTo('/')).then(() => {
        setTimeout(performScroll, 250);
      });
    }
    else {
      performScroll();
    }
  }

  return { scrollTo };
}
