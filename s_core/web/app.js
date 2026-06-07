// s_core — multicharacter selection screen
(function () {
    'use strict';
    var RESOURCE = 's_core';
    var app = document.getElementById('app');
    var state = { maxSlots: 5, characters: [] };

    function post(name, body) {
        return fetch('https://' + RESOURCE + '/' + name, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {})
        }).then(function (r) { return r.json().catch(function () { return {}; }); })
          .catch(function () { return {}; });
    }
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text != null) e.textContent = text;
        return e;
    }
    function money(n) { return '$' + (n || 0).toLocaleString('en-US'); }

    function charCard(c) {
        var card = el('div', 'card');
        var body = el('div', 'card__body');
        body.appendChild(el('div', 'card__name', c.name || 'Unknown'));
        body.appendChild(el('div', 'card__sub', c.charid || ''));
        var cash = el('div', 'card__money'); cash.innerHTML = 'Cash <b>' + money(c.cash) + '</b>'; body.appendChild(cash);
        var bank = el('div', 'card__money'); bank.innerHTML = 'Bank <b>' + money(c.bank) + '</b>'; body.appendChild(bank);
        card.appendChild(body);
        var actions = el('div', 'card__actions');
        var play = el('button', 'card__btn card__btn--play', 'Play');
        play.addEventListener('click', function () { post('selectCharacter', { charid: c.charid }); });
        var del = el('button', 'card__btn card__btn--del', 'Delete');
        del.addEventListener('click', function () { confirmDelete(c); });
        actions.appendChild(play); actions.appendChild(del);
        card.appendChild(actions);
        return card;
    }

    function emptyCard() {
        var card = el('div', 'card card--empty');
        card.appendChild(el('span', null, '\u002B'));
        card.appendChild(el('div', null, 'Create Character'));
        card.addEventListener('click', createForm);
        return card;
    }

    function render() {
        app.innerHTML = '';
        app.appendChild(el('div', 'sel__title', 'Select Character'));
        var grid = el('div', 'sel__grid');
        state.characters.forEach(function (c) { grid.appendChild(charCard(c)); });
        if (state.characters.length < state.maxSlots) grid.appendChild(emptyCard());
        app.appendChild(grid);
    }

    function overlay() {
        var o = el('div', 'overlay');
        app.appendChild(o);
        return o;
    }

    function createForm() {
        var o = overlay();
        var modal = el('div', 'modal');
        modal.appendChild(el('div', 'modal__head', 'New Character'));
        var b = el('div', 'modal__body');
        function field(label, ctrl) { var f = el('div', 'field'); var l = el('label', null, label); f.appendChild(l); f.appendChild(ctrl); return f; }
        var first = el('input'); first.maxLength = 24; first.placeholder = 'Bjorn';
        var last = el('input'); last.maxLength = 24; last.placeholder = 'Ironside';
        var dob = el('input'); dob.placeholder = 'DD/MM/YYYY';
        var gender = el('select');
        ['Male', 'Female'].forEach(function (g) { var op = el('option', null, g); op.value = g.toLowerCase(); gender.appendChild(op); });
        b.appendChild(field('First name', first));
        b.appendChild(field('Last name', last));
        b.appendChild(field('Date of birth', dob));
        b.appendChild(field('Gender', gender));
        var err = el('div', 'modal__err', '');
        b.appendChild(err);
        modal.appendChild(b);
        var foot = el('div', 'modal__foot');
        var back = el('button', 'mbtn', 'Back'); back.addEventListener('click', function () { app.removeChild(o); });
        var make = el('button', 'mbtn mbtn--primary', 'Create');
        make.addEventListener('click', function () {
            if (!first.value.trim() || !last.value.trim()) { err.textContent = 'First and last name are required.'; return; }
            make.disabled = true;
            post('createCharacter', {
                firstname: first.value.trim(), lastname: last.value.trim(),
                dob: dob.value.trim(), gender: gender.value
            }).then(function (res) {
                if (!res || !res.ok) { err.textContent = (res && res.reason) || 'Could not create character.'; make.disabled = false; }
                // on success the client closes the screen
            });
        });
        foot.appendChild(back); foot.appendChild(make);
        modal.appendChild(foot);
        o.appendChild(modal);
        first.focus();
    }

    function confirmDelete(c) {
        var o = overlay();
        var modal = el('div', 'modal');
        modal.appendChild(el('div', 'modal__head', 'Delete Character'));
        var b = el('div', 'modal__body');
        b.appendChild(el('div', 'card__money', 'Permanently delete ' + (c.name || 'this character') + '? This cannot be undone.'));
        modal.appendChild(b);
        var foot = el('div', 'modal__foot');
        var cancel = el('button', 'mbtn', 'Cancel'); cancel.addEventListener('click', function () { app.removeChild(o); });
        var del = el('button', 'mbtn mbtn--danger', 'Delete');
        del.addEventListener('click', function () {
            del.disabled = true;
            post('deleteCharacter', { charid: c.charid }).then(function (res) {
                if (res && res.ok) { state.characters = res.characters || []; state.maxSlots = res.maxSlots || state.maxSlots; render(); }
                else { app.removeChild(o); }
            });
        });
        foot.appendChild(cancel); foot.appendChild(del);
        modal.appendChild(foot);
        o.appendChild(modal);
    }

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        if (msg.action === 'open') {
            var d = msg.data || {};
            state.maxSlots = d.maxSlots || 5;
            state.characters = d.characters || [];
            app.classList.remove('app--hidden');
            render();
        } else if (msg.action === 'close') {
            app.classList.add('app--hidden');
            app.innerHTML = '';
        }
    });
})();
