def get_users_name(users_list):
    
    if len(users_list) == 1:
        return str(users_list[0])
    elif len(users_list) > 1:
        users_names = ", ".join([f"{users.first_name}" for users in users_list])
        return users_names
    else:
        return "No Students"
    
def get_students_ids(students_list):

    students_ids = [f"{student.id}" for student in students_list]
    return students_ids

def get_phone(user):
    if user.country_code and user.phone:
        return f"{user.country_code}{user.phone}"
    
def get_instructors_name(instructors_list):
    
    if len(instructors_list) == 1:
        return str(instructors_list[0].user)
    elif len(instructors_list) > 1:
        users_names = ", ".join([f"{instructor.user.first_name}" for instructor in instructors_list])
        return users_names
    else:
        return "No Instructors"
    
