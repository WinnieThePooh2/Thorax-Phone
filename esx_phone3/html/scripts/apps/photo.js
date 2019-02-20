(function(){

	Phone.apps['messages']       = {};
	const app                    = Phone.apps['messages'];
	const MAX_CONTACTS_ON_SCREEN = 16;
	const messageListTpl         = '{{#list}}<div class="contact" data-name="{{name}}" data-number="{{number}}"><div class="unread">{{unread}}</div><div class="contact-name">{{name}}</div></div>{{/list}}';
	let currentRow               = 0;
	let currentContact           = {};
	let messageSound

	app.open = function(data) {

		currentRow = 0;

		app.updateMessages();

		const elems = $('#app-messages .contact');

		if (elems.length > 0) 
			app.selectElem(elems[0]);

	}
})();