from app import app
with app.app_context():
    from services.account_service import RegisterService
    from models.model import db
    from controllers.console.wraps import mark_setup_completed

    RegisterService.setup(
        email='admin@ols-chatbot.local',
        name='Admin',
        password='u29Q958AHuGo9lkR',
        ip_address='127.0.0.1',
        language='en-US',
        session=db.session()
    )
    mark_setup_completed()
    print('SETUP_SUCCESS')
