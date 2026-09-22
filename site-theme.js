// Share the portfolio preference when both sites are served from the same origin.
(() => {
    const root = document.documentElement;
    const key = 'portfolio-theme';
    const normalize = value => value === 'light' || value === 'dark' ? value : 'system';
    let choice = 'system';
    try { choice = normalize(localStorage.getItem(key)); } catch { /* Storage is optional. */ }

    function apply() {
        if (choice === 'system') root.removeAttribute('data-theme');
        else root.dataset.theme = choice;
        document.querySelectorAll('[data-theme-choice]').forEach(button => {
            button.setAttribute('aria-pressed', String(button.dataset.themeChoice === choice));
        });
    }
    apply(); // Runs in the head, before the first paint.
    document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('[data-theme-choice]').forEach(button => {
            button.addEventListener('click', () => {
                choice = normalize(button.dataset.themeChoice);
                try {
                    if (choice === 'system') localStorage.removeItem(key);
                    else localStorage.setItem(key, choice);
                } catch { /* The choice still works for this page. */ }
                apply();
            });
        });
        apply();
        document.querySelectorAll('.theme-picker').forEach(picker => { picker.hidden = false; });
    });
    window.addEventListener('storage', event => {
        if (event.key === key || event.key === null) {
            choice = normalize(event.newValue);
            apply();
        }
    });
})();
