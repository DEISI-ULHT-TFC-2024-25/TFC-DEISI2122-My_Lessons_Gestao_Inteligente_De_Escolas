# events/views.py

import json
from django.forms.models import model_to_dict
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from .models import (
    ActivityModel, Activity, Camp, CampOrder, BirthdayParty
)

# ── ActivityModel ─────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def activity_model_list(request):
    """
    GET: return all ActivityModel instances, serializing fields manually
    POST: create a new ActivityModel, returning its data
    """
    if request.method == 'GET':
        objs = ActivityModel.objects.all()
        data = []
        for o in objs:
            data.append({
                'id':          o.id,
                'name':        o.name,
                'description': o.description,
                'location':    o.location_id,
                'school':      o.school_id,
                # only include URL if a file is set
                'photo':       o.photo.url if o.photo else None,
            })
        return Response(data)

    # POST → create
    d = request.data
    obj = ActivityModel.objects.create(
        name        = d.get('name', ''),
        description = d.get('description', ''),
        location_id = d.get('location'),
        school_id   = d.get('school'),
    )
    return Response({
        'id':          obj.id,
        'name':        obj.name,
        'description': obj.description,
        'location':    obj.location_id,
        'school':      obj.school_id,
        'photo':       None,
    }, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
def activity_model_detail(request, pk):
    """
    GET:    return one ActivityModel by pk
    PUT:    update fields on that instance
    DELETE: remove the instance
    """
    obj = get_object_or_404(ActivityModel, pk=pk)

    if request.method == 'GET':
        return Response({
            'id':          obj.id,
            'name':        obj.name,
            'description': obj.description,
            'location':    obj.location_id,
            'school':      obj.school_id,
            'photo':       obj.photo.url if obj.photo else None,
        })

    if request.method == 'PUT':
        d = request.data
        obj.name = d.get('name', obj.name)
        obj.description = d.get('description', obj.description)
        if 'location' in d:
            obj.location_id = d['location']
        if 'school' in d:
            obj.school_id = d['school']
        obj.save()
        return Response({
            'id':          obj.id,
            'name':        obj.name,
            'description': obj.description,
            'location':    obj.location_id,
            'school':      obj.school_id,
            'photo':       obj.photo.url if obj.photo else None,
        })

    # DELETE
    obj.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Activity ─────────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def activity_list(request):
    if request.method == 'GET':
        data = []
        for a in Activity.objects.all():
            data.append({
                'id':                   a.id,
                'name':                 a.name,
                'description':          a.description,
                'student_price':        a.student_price,
                'monitor_price':        a.monitor_price,
                'date':                 a.date,
                'price':                a.price,
                'start_time':           a.start_time,
                'end_time':             a.end_time,
                'duration_in_minutes':  a.duration_in_minutes,
                'students':             [s.id for s in a.students.all()],
                'instructors':          [i.id for i in a.instructors.all()],
                'monitors':             [m.id for m in a.monitors.all()],
                'activity_model':       a.activity_model_id,
                'school':               a.school_id,            # ← include school FK
            })
        return Response(data)

    # POST → create
    d = request.data
    a = Activity.objects.create(
        name                 = d.get('name', ''),
        description          = d.get('description', ''),
        student_price        = d.get('student_price'),
        monitor_price        = d.get('monitor_price'),
        date                 = d.get('date'),
        price                = d.get('price'),
        start_time           = d.get('start_time'),
        end_time             = d.get('end_time'),
        duration_in_minutes  = d.get('duration_in_minutes'),
        activity_model_id    = d.get('activity_model'),
        school_id            = d.get('school'),          # ← set school FK
    )
    # M2M assignments
    if 'students' in d:
        a.students.set(d['students'])
    if 'instructors' in d:
        a.instructors.set(d['instructors'])
    if 'monitors' in d:
        a.monitors.set(d['monitors'])

    return Response({
        'id':                   a.id,
        'name':                 a.name,
        'description':          a.description,
        'student_price':        a.student_price,
        'monitor_price':        a.monitor_price,
        'date':                 a.date,
        'price':                a.price,
        'start_time':           a.start_time,
        'end_time':             a.end_time,
        'duration_in_minutes':  a.duration_in_minutes,
        'students':             [s.id for s in a.students.all()],
        'instructors':          [i.id for i in a.instructors.all()],
        'monitors':             [m.id for m in a.monitors.all()],
        'activity_model':       a.activity_model_id,
        'school':               a.school_id,             # ← include school in response
    }, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
def activity_detail(request, pk):
    a = get_object_or_404(Activity, pk=pk)

    if request.method == 'GET':
        return Response({
            'id':                   a.id,
            'name':                 a.name,
            'description':          a.description,
            'student_price':        a.student_price,
            'monitor_price':        a.monitor_price,
            'date':                 a.date,
            'price':                a.price,
            'start_time':           a.start_time,
            'end_time':             a.end_time,
            'duration_in_minutes':  a.duration_in_minutes,
            'students':             [s.id for s in a.students.all()],
            'instructors':          [i.id for i in a.instructors.all()],
            'monitors':             [m.id for m in a.monitors.all()],
            'activity_model':       a.activity_model_id,
            'school':               a.school_id,             # ← include school FK
        })

    if request.method == 'PUT':
        d = request.data
        for fld in ['name', 'description', 'student_price', 'monitor_price',
                    'date', 'price', 'start_time', 'end_time', 'duration_in_minutes']:
            if fld in d:
                setattr(a, fld, d[fld])
        if 'activity_model' in d:
            a.activity_model_id = d['activity_model']
        if 'school' in d:
            a.school_id = d['school']                          # ← update school FK
        a.save()

        # update M2M
        if 'students' in d:
            a.students.set(d['students'])
        if 'instructors' in d:
            a.instructors.set(d['instructors'])
        if 'monitors' in d:
            a.monitors.set(d['monitors'])

        return Response({
            'id':                   a.id,
            'name':                 a.name,
            'description':          a.description,
            'student_price':        a.student_price,
            'monitor_price':        a.monitor_price,
            'date':                 a.date,
            'price':                a.price,
            'start_time':           a.start_time,
            'end_time':             a.end_time,
            'duration_in_minutes':  a.duration_in_minutes,
            'students':             [s.id for s in a.students.all()],
            'instructors':          [i.id for i in a.instructors.all()],
            'monitors':             [m.id for m in a.monitors.all()],
            'activity_model':       a.activity_model_id,
            'school':               a.school_id,             # ← include updated school
        })

    # DELETE
    a.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── Camp ─────────────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def camp_list(request):
    if request.method == 'GET':
        camps = []
        for c in Camp.objects.all():
            camps.append({
                'id':           c.id,
                'name':         c.name,
                'start_date':   c.start_date,
                'end_date':     c.end_date,
                'is_finished':  c.is_finished,
                'school':       c.school_id,
                'activities':   list(c.activities.values_list('id', flat=True)),
            })
        return Response(camps)

    # POST → create camp, computing start/end from activities
    d = request.data
    activity_ids = d.get('activities', [])

    # Compute start_date / end_date
    start_date = None
    end_date   = None
    if activity_ids:
        qs = Activity.objects.filter(id__in=activity_ids).order_by('date')
        if qs.exists():
            start_date = qs.first().date
            end_date   = qs.last().date

    # Create Camp
    c = Camp.objects.create(
        name        = d.get('name', ''),
        start_date  = start_date,
        end_date    = end_date,
        is_finished = d.get('is_finished', False),
        school_id   = d.get('school'),
    )

    # Set the M2M activities
    if activity_ids:
        c.activities.set(activity_ids)

    # Serialize the newly created camp
    result = {
        'id':           c.id,
        'name':         c.name,
        'start_date':   c.start_date,
        'end_date':     c.end_date,
        'is_finished':  c.is_finished,
        'school':       c.school_id,
        'activities':   list(c.activities.values_list('id', flat=True)),
    }
    return Response(result, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
def camp_detail(request, pk):
    c = get_object_or_404(Camp, pk=pk)

    if request.method == 'GET':
        return Response(model_to_dict(c))

    if request.method == 'PUT':
        d = request.data
        for fld in ['name','start_date','end_date','is_finished']:
            if fld in d:
                setattr(c, fld, d[fld])
        if 'school' in d:
            c.school_id = d['school']
        c.save()
        if 'activities' in d:
            c.activities.set(d['activities'])
        return Response(model_to_dict(c))

    c.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── CampOrder ────────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def camp_order_list(request):
    if request.method == 'GET':
        return Response([model_to_dict(o) for o in CampOrder.objects.all()])

    d = request.data
    o = CampOrder.objects.create(
        user_id=d.get('user'),
        student_id=d.get('student'),
        is_half_paid=d.get('is_half_paid', False),
        is_fully_paid=d.get('is_fully_paid', False),
        date=d.get('date'),
        time=d.get('time'),
        price=d.get('price'),
        school_id=d.get('school'),
    )
    if 'activities' in d:
        o.activities.set(d['activities'])
    return Response(model_to_dict(o), status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
def camp_order_detail(request, pk):
    o = get_object_or_404(CampOrder, pk=pk)

    if request.method == 'GET':
        return Response(model_to_dict(o))

    if request.method == 'PUT':
        d = request.data
        for fld in ['is_half_paid','is_fully_paid','date','time','price']:
            if fld in d:
                setattr(o, fld, d[fld])
        if 'user' in d:
            o.user_id = d['user']
        if 'student' in d:
            o.student_id = d['student']
        if 'school' in d:
            o.school_id = d['school']
        o.save()
        if 'activities' in d:
            o.activities.set(d['activities'])
        return Response(model_to_dict(o))

    o.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ── BirthdayParty ────────────────────────────────────────────────────────────

@api_view(['GET', 'POST'])
def birthday_party_list(request):
    if request.method == 'GET':
        return Response([model_to_dict(b) for b in BirthdayParty.objects.all()])

    d = request.data
    b = BirthdayParty.objects.create(
        date=d.get('date'),
        start_time=d.get('start_time'),
        end_time=d.get('end_time'),
        duration_in_minutes=d.get('duration_in_minutes'),
        number_of_guests=d.get('number_of_guests'),
        equipment=d.get('equipment', {}),
        price=d.get('price'),
    )
    if 'activities' in d:
        b.activities.set(d['activities'])
    if 'students' in d:
        b.students.set(d['students'])
    return Response(model_to_dict(b), status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
def birthday_party_detail(request, pk):
    b = get_object_or_404(BirthdayParty, pk=pk)

    if request.method == 'GET':
        return Response(model_to_dict(b))

    if request.method == 'PUT':
        d = request.data
        for fld in ['date','start_time','end_time','duration_in_minutes',
                    'number_of_guests','equipment','price']:
            if fld in d:
                setattr(b, fld, d[fld])
        b.save()
        if 'activities' in d:
            b.activities.set(d['activities'])
        if 'students' in d:
            b.students.set(d['students'])
        return Response(model_to_dict(b))

    b.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)
